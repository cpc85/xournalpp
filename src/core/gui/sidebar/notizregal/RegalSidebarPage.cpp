/*
 * Xournal++ – Notizregal-Fork. Siehe RegalSidebarPage.h.
 * Ziel-Toolkit GTK3 (gtk4_helper-Shims). Kompiliert wird über die CI.
 *
 * @license GNU GPLv2 or later
 */
#include "RegalSidebarPage.h"

#include <algorithm>
#include <cctype>

#include <pango/pangocairo.h>

#include "control/Control.h"
#include "util/PathUtil.h"
#include "util/gtk4_helper.h"
#include "util/i18n.h"

namespace xoj::notizregal {

namespace {
struct TileRef {
    RegalSidebarPage* self;
    NotebookEntry* entry;
};

std::string toLower(std::string s) {
    std::transform(s.begin(), s.end(), s.begin(), [](unsigned char c) { return static_cast<char>(std::tolower(c)); });
    return s;
}

std::string pathToString(const fs::path& p) {
    try {
        return p.string();
    } catch (...) {
        return {};
    }
}

std::string entryId(const fs::path& p) {
    std::string s = toLower(pathToString(p));
    gchar* sum = g_compute_checksum_for_string(G_CHECKSUM_SHA256, s.c_str(), static_cast<gssize>(s.size()));
    std::string id = sum ? sum : "0";
    if (sum) {
        g_free(sum);
    }
    return "note-" + id;
}
}  // namespace

RegalSidebarPage::RegalSidebarPage(Control* control): AbstractSidebarPage(control) {
    loadCatalog();
    buildUi();
    // Erste Befüllung erfolgt beim ersten Anzeigen (enableSidebar), damit der
    // Start nicht durch das Scannen der Ordner verzögert wird.
}

RegalSidebarPage::~RegalSidebarPage() = default;

std::string RegalSidebarPage::getName() { return _("Regal"); }
std::string RegalSidebarPage::getIconName() { return "xopp-regal"; }
bool RegalSidebarPage::hasData() { return true; }
GtkWidget* RegalSidebarPage::getWidget() { return root; }
void RegalSidebarPage::layout() {}

void RegalSidebarPage::enableSidebar() {
    if (!scanned) {
        scanFolders();
        rebuildTiles();
        scanned = true;
    }
}

void RegalSidebarPage::disableSidebar() {}

fs::path RegalSidebarPage::catalogFile() const {
    fs::path dir = Util::getConfigSubfolder("notizregal");
    return dir / "katalog.ini";
}

std::uint32_t RegalSidebarPage::defaultColorFor(const std::string& title) {
    static const std::uint32_t palette[] = {0x153e37, 0x4c6557, 0x6b4b3e, 0x3b4a6b,
                                            0x7a3b5b, 0x8a5a1e, 0x2f6b6b, 0x5b4b7a};
    guint h = g_str_hash(title.c_str());
    return palette[h % (sizeof(palette) / sizeof(palette[0]))];
}

void RegalSidebarPage::loadCatalog() {
    folders.clear();
    GKeyFile* kf = g_key_file_new();
    std::string file = pathToString(catalogFile());
    if (g_key_file_load_from_file(kf, file.c_str(), G_KEY_FILE_NONE, nullptr)) {
        gsize n = 0;
        gchar** arr = g_key_file_get_string_list(kf, "settings", "folders", &n, nullptr);
        if (arr) {
            for (gsize i = 0; i < n; i++) {
                if (arr[i] && *arr[i]) {
                    folders.emplace_back(fs::path(arr[i]));
                }
            }
            g_strfreev(arr);
        }
    }
    g_key_file_free(kf);
}

void RegalSidebarPage::scanFolders() {
    entries.clear();
    GKeyFile* meta = g_key_file_new();
    std::string file = pathToString(catalogFile());
    g_key_file_load_from_file(meta, file.c_str(), G_KEY_FILE_NONE, nullptr);

    for (const auto& folder: folders) {
        std::error_code ec;
        if (!fs::exists(folder, ec) || !fs::is_directory(folder, ec)) {
            continue;
        }
        auto it = fs::recursive_directory_iterator(folder, fs::directory_options::skip_permission_denied, ec);
        fs::recursive_directory_iterator end;
        for (; it != end; it.increment(ec)) {
            if (ec) {
                break;
            }
            std::error_code fec;
            if (!it->is_regular_file(fec)) {
                continue;
            }
            std::string ext = toLower(it->path().extension().string());
            bool isXopp = (ext == ".xopp");
            bool isPdf = (ext == ".pdf");
            if (!isXopp && !isPdf) {
                continue;
            }
            auto e = std::make_unique<NotebookEntry>();
            e->path = it->path();
            e->isPdf = isPdf;
            std::string stem = it->path().stem().string();
            std::string id = entryId(e->path);

            gchar* title = g_key_file_get_string(meta, id.c_str(), "title", nullptr);
            e->title = (title && *title) ? std::string(title) : stem;
            if (title) {
                g_free(title);
            }
            gchar* cat = g_key_file_get_string(meta, id.c_str(), "category", nullptr);
            e->category = cat ? std::string(cat) : std::string();
            if (cat) {
                g_free(cat);
            }
            GError* colErr = nullptr;
            gint col = g_key_file_get_integer(meta, id.c_str(), "color", &colErr);
            if (colErr) {
                e->color = defaultColorFor(e->title);
                g_error_free(colErr);
            } else {
                e->color = static_cast<std::uint32_t>(col) & 0xffffffu;
            }
            e->favorite = g_key_file_get_boolean(meta, id.c_str(), "favorite", nullptr) ? true : false;

            entries.push_back(std::move(e));
            if (entries.size() > 5000) {
                break;
            }
        }
    }
    g_key_file_free(meta);

    std::sort(entries.begin(), entries.end(),
              [](const std::unique_ptr<NotebookEntry>& a, const std::unique_ptr<NotebookEntry>& b) {
                  return toLower(a->title) < toLower(b->title);
              });
}

void RegalSidebarPage::saveCatalog() {
    GKeyFile* kf = g_key_file_new();

    std::vector<std::string> folderStrings;
    std::vector<const gchar*> folderPtrs;
    folderStrings.reserve(folders.size());
    for (const auto& f: folders) {
        folderStrings.push_back(pathToString(f));
        folderPtrs.push_back(folderStrings.back().c_str());
    }
    if (!folderPtrs.empty()) {
        g_key_file_set_string_list(kf, "settings", "folders", folderPtrs.data(), folderPtrs.size());
    }

    for (const auto& e: entries) {
        std::string id = entryId(e->path);
        g_key_file_set_string(kf, id.c_str(), "path", pathToString(e->path).c_str());
        g_key_file_set_string(kf, id.c_str(), "title", e->title.c_str());
        g_key_file_set_string(kf, id.c_str(), "category", e->category.c_str());
        g_key_file_set_integer(kf, id.c_str(), "color", static_cast<gint>(e->color));
        g_key_file_set_boolean(kf, id.c_str(), "favorite", e->favorite ? TRUE : FALSE);
    }

    std::string file = pathToString(catalogFile());
    g_key_file_save_to_file(kf, file.c_str(), nullptr);
    g_key_file_free(kf);
}

void RegalSidebarPage::buildUi() {
    root = gtk_box_new(GTK_ORIENTATION_VERTICAL, 6);

    GtkWidget* header = gtk_box_new(GTK_ORIENTATION_VERTICAL, 4);
    gtk_widget_set_margin_start(header, 6);
    gtk_widget_set_margin_end(header, 6);
    gtk_widget_set_margin_top(header, 6);
    gtk_box_append(GTK_BOX(root), header);

    searchEntry = gtk_search_entry_new();
    g_signal_connect(searchEntry, "search-changed", G_CALLBACK(onSearchChanged), this);
    gtk_box_append(GTK_BOX(header), searchEntry);

    GtkWidget* row = gtk_box_new(GTK_ORIENTATION_HORIZONTAL, 4);
    GtkWidget* addBtn = gtk_button_new_with_label(_("Ordner …"));
    gtk_widget_set_tooltip_text(addBtn, _("Notizordner hinzufügen"));
    g_signal_connect(addBtn, "clicked", G_CALLBACK(onAddFolder), this);
    gtk_widget_set_hexpand(addBtn, TRUE);
    gtk_box_append(GTK_BOX(row), addBtn);
    GtkWidget* newBtn = gtk_button_new_with_label(_("＋"));
    gtk_widget_set_tooltip_text(newBtn, _("Neues Notizbuch"));
    g_signal_connect(newBtn, "clicked", G_CALLBACK(onNew), this);
    gtk_box_append(GTK_BOX(row), newBtn);
    GtkWidget* refreshBtn = gtk_button_new_with_label(_("⟳"));
    gtk_widget_set_tooltip_text(refreshBtn, _("Aktualisieren"));
    g_signal_connect(refreshBtn, "clicked", G_CALLBACK(onRefresh), this);
    gtk_box_append(GTK_BOX(row), refreshBtn);
    favToggle = gtk_toggle_button_new_with_label(_("★"));
    gtk_widget_set_tooltip_text(favToggle, _("Nur Favoriten"));
    g_signal_connect(favToggle, "toggled", G_CALLBACK(onFavToggle), this);
    gtk_box_append(GTK_BOX(row), favToggle);
    gtk_box_append(GTK_BOX(header), row);

    GtkWidget* scrolled = gtk_scrolled_window_new();
    gtk_widget_set_vexpand(scrolled, TRUE);
    gtk_box_append(GTK_BOX(root), scrolled);

    flowbox = gtk_flow_box_new();
    gtk_flow_box_set_selection_mode(GTK_FLOW_BOX(flowbox), GTK_SELECTION_NONE);
    gtk_flow_box_set_homogeneous(GTK_FLOW_BOX(flowbox), TRUE);
    gtk_flow_box_set_max_children_per_line(GTK_FLOW_BOX(flowbox), 8);
    gtk_flow_box_set_row_spacing(GTK_FLOW_BOX(flowbox), 8);
    gtk_flow_box_set_column_spacing(GTK_FLOW_BOX(flowbox), 8);
    gtk_widget_set_margin_start(flowbox, 6);
    gtk_widget_set_margin_end(flowbox, 6);
    gtk_flow_box_set_filter_func(GTK_FLOW_BOX(flowbox), filterFunc, this, nullptr);
    gtk_scrolled_window_set_child(GTK_SCROLLED_WINDOW(scrolled), flowbox);

    statusLabel = gtk_label_new("");
    gtk_widget_set_halign(statusLabel, GTK_ALIGN_START);
    gtk_widget_set_margin_start(statusLabel, 6);
    gtk_widget_set_margin_bottom(statusLabel, 4);
    gtk_box_append(GTK_BOX(root), statusLabel);

    gtk_widget_show_all(root);
}

void RegalSidebarPage::rebuildTiles() {
    if (!flowbox) {
        return;
    }
    GList* children = gtk_container_get_children(GTK_CONTAINER(flowbox));
    for (GList* l = children; l != nullptr; l = l->next) {
        gtk_widget_destroy(GTK_WIDGET(l->data));
    }
    g_list_free(children);

    for (auto& e: entries) {
        NotebookEntry* entry = e.get();

        GtkWidget* tile = gtk_box_new(GTK_ORIENTATION_VERTICAL, 2);
        entry->tile = tile;
        g_object_set_data(G_OBJECT(tile), "nz-entry", entry);

        GtkWidget* coverBtn = gtk_button_new();
        GtkWidget* cover = gtk_drawing_area_new();
        gtk_widget_set_size_request(cover, 132, 84);
        gtk_drawing_area_set_draw_func(GTK_DRAWING_AREA(cover), onCoverDraw, entry, nullptr);
        gtk_button_set_child(GTK_BUTTON(coverBtn), cover);

        auto* ref = new TileRef{this, entry};
        g_object_set_data_full(G_OBJECT(coverBtn), "nz-ref", ref,
                               [](gpointer p) { delete static_cast<TileRef*>(p); });
        g_signal_connect(coverBtn, "clicked", G_CALLBACK(+[](GtkButton*, gpointer d) {
                             auto* r = static_cast<TileRef*>(d);
                             r->self->openEntry(r->entry);
                         }),
                         ref);
        gtk_box_append(GTK_BOX(tile), coverBtn);

        GtkWidget* titleLbl = gtk_label_new(entry->title.c_str());
        gtk_label_set_max_width_chars(GTK_LABEL(titleLbl), 16);
        gtk_label_set_ellipsize(GTK_LABEL(titleLbl), PANGO_ELLIPSIZE_END);
        gtk_widget_set_tooltip_text(titleLbl, pathToString(entry->path).c_str());
        gtk_box_append(GTK_BOX(tile), titleLbl);

        GtkWidget* actions = gtk_box_new(GTK_ORIENTATION_HORIZONTAL, 2);
        gtk_widget_set_halign(actions, GTK_ALIGN_CENTER);

        GtkWidget* favBtn = gtk_button_new_with_label(entry->favorite ? "★" : "☆");
        gtk_widget_set_tooltip_text(favBtn, _("Favorit"));
        auto* fref = new TileRef{this, entry};
        g_object_set_data_full(G_OBJECT(favBtn), "nz-ref", fref,
                               [](gpointer p) { delete static_cast<TileRef*>(p); });
        g_signal_connect(favBtn, "clicked", G_CALLBACK(+[](GtkButton* b, gpointer d) {
                             auto* r = static_cast<TileRef*>(d);
                             r->self->toggleFavorite(r->entry);
                             gtk_button_set_label(b, r->entry->favorite ? "★" : "☆");
                         }),
                         fref);
        gtk_box_append(GTK_BOX(actions), favBtn);

        GtkWidget* editBtn = gtk_button_new_with_label("✎");
        gtk_widget_set_tooltip_text(editBtn, _("Titel, Kategorie und Farbe bearbeiten"));
        auto* eref = new TileRef{this, entry};
        g_object_set_data_full(G_OBJECT(editBtn), "nz-ref", eref,
                               [](gpointer p) { delete static_cast<TileRef*>(p); });
        g_signal_connect(editBtn, "clicked", G_CALLBACK(+[](GtkButton*, gpointer d) {
                             auto* r = static_cast<TileRef*>(d);
                             r->self->editEntry(r->entry);
                         }),
                         eref);
        gtk_box_append(GTK_BOX(actions), editBtn);

        gtk_box_append(GTK_BOX(tile), actions);

        gtk_flow_box_insert(GTK_FLOW_BOX(flowbox), tile, -1);
    }

    gtk_widget_show_all(flowbox);

    if (statusLabel) {
        std::string s;
        if (folders.empty()) {
            s = _("Kein Ordner. „Ordner …“ wählen.");
        } else {
            s = std::to_string(entries.size()) + " " + _("Einträge");
        }
        gtk_label_set_text(GTK_LABEL(statusLabel), s.c_str());
    }
    gtk_flow_box_invalidate_filter(GTK_FLOW_BOX(flowbox));
}

void RegalSidebarPage::openEntry(NotebookEntry* e) {
    if (e) {
        control->openFile(e->path);
    }
}

void RegalSidebarPage::toggleFavorite(NotebookEntry* e) {
    if (!e) {
        return;
    }
    e->favorite = !e->favorite;
    saveCatalog();
    gtk_flow_box_invalidate_filter(GTK_FLOW_BOX(flowbox));
}

void RegalSidebarPage::editEntry(NotebookEntry* e) {
    if (!e) {
        return;
    }
    GtkWidget* dlg = gtk_dialog_new_with_buttons(
            _("Notizbuch bearbeiten"), control->getGtkWindow(),
            static_cast<GtkDialogFlags>(GTK_DIALOG_MODAL | GTK_DIALOG_DESTROY_WITH_PARENT), _("Abbrechen"),
            GTK_RESPONSE_CANCEL, _("Speichern"), GTK_RESPONSE_ACCEPT, nullptr);

    GtkWidget* grid = gtk_grid_new();
    gtk_grid_set_row_spacing(GTK_GRID(grid), 8);
    gtk_grid_set_column_spacing(GTK_GRID(grid), 8);
    gtk_widget_set_margin_start(grid, 12);
    gtk_widget_set_margin_end(grid, 12);
    gtk_widget_set_margin_top(grid, 12);
    gtk_widget_set_margin_bottom(grid, 12);

    GtkWidget* titleLbl = gtk_label_new(_("Titel"));
    gtk_widget_set_halign(titleLbl, GTK_ALIGN_START);
    GtkWidget* titleEntry = gtk_entry_new();
    gtk_editable_set_text(GTK_EDITABLE(titleEntry), e->title.c_str());
    gtk_widget_set_hexpand(titleEntry, TRUE);
    gtk_grid_attach(GTK_GRID(grid), titleLbl, 0, 0, 1, 1);
    gtk_grid_attach(GTK_GRID(grid), titleEntry, 1, 0, 1, 1);

    GtkWidget* catLbl = gtk_label_new(_("Kategorie"));
    gtk_widget_set_halign(catLbl, GTK_ALIGN_START);
    GtkWidget* catEntry = gtk_entry_new();
    gtk_editable_set_text(GTK_EDITABLE(catEntry), e->category.c_str());
    gtk_grid_attach(GTK_GRID(grid), catLbl, 0, 1, 1, 1);
    gtk_grid_attach(GTK_GRID(grid), catEntry, 1, 1, 1, 1);

    GtkWidget* colLbl = gtk_label_new(_("Coverfarbe"));
    gtk_widget_set_halign(colLbl, GTK_ALIGN_START);
    GdkRGBA rgba;
    rgba.red = ((e->color >> 16) & 0xff) / 255.0;
    rgba.green = ((e->color >> 8) & 0xff) / 255.0;
    rgba.blue = (e->color & 0xff) / 255.0;
    rgba.alpha = 1.0;
    GtkWidget* colorBtn = gtk_color_button_new_with_rgba(&rgba);
    gtk_widget_set_halign(colorBtn, GTK_ALIGN_START);
    gtk_grid_attach(GTK_GRID(grid), colLbl, 0, 2, 1, 1);
    gtk_grid_attach(GTK_GRID(grid), colorBtn, 1, 2, 1, 1);

    GtkWidget* favChk = gtk_check_button_new_with_label(_("Favorit"));
    gtk_check_button_set_active(GTK_CHECK_BUTTON(favChk), e->favorite);
    gtk_grid_attach(GTK_GRID(grid), favChk, 1, 3, 1, 1);

    GtkWidget* content = gtk_dialog_get_content_area(GTK_DIALOG(dlg));
    gtk_box_append(GTK_BOX(content), grid);
    gtk_widget_show_all(dlg);

    if (gtk_dialog_run(GTK_DIALOG(dlg)) == GTK_RESPONSE_ACCEPT) {
        const char* t = gtk_editable_get_text(GTK_EDITABLE(titleEntry));
        const char* c = gtk_editable_get_text(GTK_EDITABLE(catEntry));
        e->title = t ? t : "";
        e->category = c ? c : "";
        GdkRGBA out;
        gtk_color_chooser_get_rgba(GTK_COLOR_CHOOSER(colorBtn), &out);
        std::uint32_t r = static_cast<std::uint32_t>(out.red * 255.0 + 0.5) & 0xff;
        std::uint32_t g = static_cast<std::uint32_t>(out.green * 255.0 + 0.5) & 0xff;
        std::uint32_t b = static_cast<std::uint32_t>(out.blue * 255.0 + 0.5) & 0xff;
        e->color = (r << 16) | (g << 8) | b;
        e->favorite = gtk_check_button_get_active(GTK_CHECK_BUTTON(favChk));
        saveCatalog();
        rebuildTiles();
    }
    gtk_widget_destroy(dlg);
}

void RegalSidebarPage::refresh() {
    scanFolders();
    rebuildTiles();
}

void RegalSidebarPage::newNotebook() {
    // Neues leeres Notizbuch anlegen; der Nutzer speichert es in seinen
    // Notizordner, „Aktualisieren“ zeigt es danach an.
    control->newFile();
}

void RegalSidebarPage::onRefresh(GtkButton*, gpointer self) { static_cast<RegalSidebarPage*>(self)->refresh(); }
void RegalSidebarPage::onNew(GtkButton*, gpointer self) { static_cast<RegalSidebarPage*>(self)->newNotebook(); }

void RegalSidebarPage::addFolderDialog() {
    GtkWidget* dialog = gtk_file_chooser_dialog_new(_("Notizordner hinzufügen"), control->getGtkWindow(),
                                                    GTK_FILE_CHOOSER_ACTION_SELECT_FOLDER, _("Abbrechen"),
                                                    GTK_RESPONSE_CANCEL, _("Hinzufügen"), GTK_RESPONSE_ACCEPT, nullptr);
    if (gtk_dialog_run(GTK_DIALOG(dialog)) == GTK_RESPONSE_ACCEPT) {
        gchar* name = gtk_file_chooser_get_filename(GTK_FILE_CHOOSER(dialog));
        if (name) {
            folders.emplace_back(fs::path(name));
            g_free(name);
            saveCatalog();
            scanFolders();
            rebuildTiles();
        }
    }
    gtk_widget_destroy(dialog);
}

void RegalSidebarPage::onSearchChanged(GtkSearchEntry* entry, gpointer self) {
    auto* w = static_cast<RegalSidebarPage*>(self);
    const char* t = gtk_editable_get_text(GTK_EDITABLE(entry));
    w->filterText = toLower(t ? t : "");
    gtk_flow_box_invalidate_filter(GTK_FLOW_BOX(w->flowbox));
}

void RegalSidebarPage::onAddFolder(GtkButton*, gpointer self) { static_cast<RegalSidebarPage*>(self)->addFolderDialog(); }

void RegalSidebarPage::onFavToggle(GtkToggleButton* b, gpointer self) {
    auto* w = static_cast<RegalSidebarPage*>(self);
    w->onlyFavorites = gtk_toggle_button_get_active(b);
    gtk_flow_box_invalidate_filter(GTK_FLOW_BOX(w->flowbox));
}

gboolean RegalSidebarPage::filterFunc(GtkFlowBoxChild* child, gpointer self) {
    auto* w = static_cast<RegalSidebarPage*>(self);
    GtkWidget* tile = gtk_bin_get_child(GTK_BIN(child));
    if (!tile) {
        return TRUE;
    }
    auto* e = static_cast<NotebookEntry*>(g_object_get_data(G_OBJECT(tile), "nz-entry"));
    if (!e) {
        return TRUE;
    }
    if (w->onlyFavorites && !e->favorite) {
        return FALSE;
    }
    if (w->filterText.empty()) {
        return TRUE;
    }
    std::string hay = toLower(e->title) + " " + toLower(e->category) + " " + toLower(pathToString(e->path));
    return hay.find(w->filterText) != std::string::npos ? TRUE : FALSE;
}

void RegalSidebarPage::onCoverDraw(GtkDrawingArea*, cairo_t* cr, int width, int height, gpointer data) {
    auto* e = static_cast<NotebookEntry*>(data);
    std::uint32_t c = e ? e->color : 0x4c6557u;
    double r = ((c >> 16) & 0xff) / 255.0;
    double g = ((c >> 8) & 0xff) / 255.0;
    double b = (c & 0xff) / 255.0;
    cairo_set_source_rgb(cr, r, g, b);
    cairo_paint(cr);

    cairo_set_source_rgba(cr, 0, 0, 0, 0.18);
    cairo_rectangle(cr, 0, 0, 7, height);
    cairo_fill(cr);

    double lum = 0.299 * r + 0.587 * g + 0.114 * b;
    double tc = (lum < 0.55) ? 1.0 : 0.0;
    cairo_set_source_rgb(cr, tc, tc, tc);

    PangoLayout* layout = pango_cairo_create_layout(cr);
    pango_layout_set_width(layout, (width - 20) * PANGO_SCALE);
    pango_layout_set_wrap(layout, PANGO_WRAP_WORD_CHAR);
    pango_layout_set_ellipsize(layout, PANGO_ELLIPSIZE_END);
    pango_layout_set_height(layout, (height - 28) * PANGO_SCALE);
    PangoFontDescription* fd = pango_font_description_from_string("Sans Bold 10");
    pango_layout_set_font_description(layout, fd);
    pango_font_description_free(fd);
    pango_layout_set_text(layout, e ? e->title.c_str() : "", -1);
    cairo_move_to(cr, 13, 8);
    pango_cairo_show_layout(cr, layout);

    if (e && !e->category.empty()) {
        PangoFontDescription* fd2 = pango_font_description_from_string("Sans 7");
        pango_layout_set_font_description(layout, fd2);
        pango_font_description_free(fd2);
        pango_layout_set_height(layout, -1);
        pango_layout_set_text(layout, e->category.c_str(), -1);
        cairo_move_to(cr, 13, height - 18);
        pango_cairo_show_layout(cr, layout);
    }
    g_object_unref(layout);
}

}  // namespace xoj::notizregal
