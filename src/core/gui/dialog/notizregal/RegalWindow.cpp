/*
 * Xournal++ – Notizregal-Fork
 * Natives Notizbuchregal-Fenster. Siehe RegalWindow.h.
 * Ziel-Toolkit: GTK3 (mit gtk4_helper-Shims). Kompiliert wird über die CI.
 *
 * @license GNU GPLv2 or later
 */
#include "RegalWindow.h"

#include <algorithm>
#include <cctype>

#include <pango/pangocairo.h>

#include "control/Control.h"
#include "util/PathUtil.h"
#include "util/gtk4_helper.h"
#include "util/i18n.h"

namespace xoj::notizregal {

namespace {
// Verknüpft ein Kachel-Widget mit Fenster + Eintrag für Callbacks.
struct TileRef {
    RegalWindow* self;
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

RegalWindow::RegalWindow(Control* control): control(control) {
    loadCatalog();
    scanFolders();
    buildUi();
    rebuildTiles();
}

RegalWindow::~RegalWindow() = default;

fs::path RegalWindow::catalogFile() const {
    fs::path dir = Util::getConfigSubfolder("notizregal");
    return dir / "katalog.ini";
}

std::uint32_t RegalWindow::defaultColorFor(const std::string& title) {
    static const std::uint32_t palette[] = {0x153e37, 0x4c6557, 0x6b4b3e, 0x3b4a6b,
                                            0x7a3b5b, 0x8a5a1e, 0x2f6b6b, 0x5b4b7a};
    guint h = g_str_hash(title.c_str());
    return palette[h % (sizeof(palette) / sizeof(palette[0]))];
}

void RegalWindow::loadCatalog() {
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

void RegalWindow::scanFolders() {
    entries.clear();
    // Metadaten (Titel/Kategorie/Farbe/Favorit) aus der Katalogdatei lesen.
    GKeyFile* meta = g_key_file_new();
    std::string file = pathToString(catalogFile());
    g_key_file_load_from_file(meta, file.c_str(), G_KEY_FILE_NONE, nullptr);

    for (const auto& folder : folders) {
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
                break;  // Schutz gegen riesige Ordner
            }
        }
    }
    g_key_file_free(meta);

    std::sort(entries.begin(), entries.end(),
              [](const std::unique_ptr<NotebookEntry>& a, const std::unique_ptr<NotebookEntry>& b) {
                  return toLower(a->title) < toLower(b->title);
              });
}

void RegalWindow::saveCatalog() {
    GKeyFile* kf = g_key_file_new();

    std::vector<std::string> folderStrings;
    folderStrings.reserve(folders.size());
    std::vector<const gchar*> folderPtrs;
    for (const auto& f : folders) {
        folderStrings.push_back(pathToString(f));
        folderPtrs.push_back(folderStrings.back().c_str());
    }
    if (!folderPtrs.empty()) {
        g_key_file_set_string_list(kf, "settings", "folders", folderPtrs.data(), folderPtrs.size());
    }

    for (const auto& e : entries) {
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

void RegalWindow::buildUi() {
    GtkWidget* win = gtk_window_new(GTK_WINDOW_TOPLEVEL);
    gtk_window_set_title(GTK_WINDOW(win), _("Notizbuchregal"));
    gtk_window_set_default_size(GTK_WINDOW(win), 820, 640);
    window.reset(GTK_WINDOW(win));

    GtkWidget* vbox = gtk_box_new(GTK_ORIENTATION_VERTICAL, 8);
    gtk_container_add(GTK_CONTAINER(win), vbox);

    // Kopfzeile: Suche + Ordner hinzufügen + Favoriten-Filter
    GtkWidget* header = gtk_box_new(GTK_ORIENTATION_HORIZONTAL, 8);
    gtk_widget_set_margin_start(header, 10);
    gtk_widget_set_margin_end(header, 10);
    gtk_widget_set_margin_top(header, 10);
    gtk_box_append(GTK_BOX(vbox), header);

    searchEntry = gtk_search_entry_new();
    gtk_widget_set_hexpand(searchEntry, TRUE);
    g_signal_connect(searchEntry, "search-changed", G_CALLBACK(onSearchChanged), this);
    gtk_box_append(GTK_BOX(header), searchEntry);

    GtkWidget* addBtn = gtk_button_new_with_label(_("Ordner hinzufügen …"));
    g_signal_connect(addBtn, "clicked", G_CALLBACK(onAddFolder), this);
    gtk_box_append(GTK_BOX(header), addBtn);

    favToggle = gtk_toggle_button_new_with_label(_("★ Favoriten"));
    g_signal_connect(favToggle, "toggled", G_CALLBACK(onFavToggle), this);
    gtk_box_append(GTK_BOX(header), favToggle);

    // Cover-Kacheln in einem scrollbaren FlowBox
    GtkWidget* scrolled = gtk_scrolled_window_new();
    gtk_widget_set_vexpand(scrolled, TRUE);
    gtk_widget_set_hexpand(scrolled, TRUE);
    gtk_box_append(GTK_BOX(vbox), scrolled);

    flowbox = gtk_flow_box_new();
    gtk_flow_box_set_selection_mode(GTK_FLOW_BOX(flowbox), GTK_SELECTION_NONE);
    gtk_flow_box_set_homogeneous(GTK_FLOW_BOX(flowbox), TRUE);
    gtk_flow_box_set_max_children_per_line(GTK_FLOW_BOX(flowbox), 20);
    gtk_flow_box_set_row_spacing(GTK_FLOW_BOX(flowbox), 10);
    gtk_flow_box_set_column_spacing(GTK_FLOW_BOX(flowbox), 10);
    gtk_widget_set_margin_start(flowbox, 10);
    gtk_widget_set_margin_end(flowbox, 10);
    gtk_flow_box_set_filter_func(GTK_FLOW_BOX(flowbox), filterFunc, this, nullptr);
    gtk_scrolled_window_set_child(GTK_SCROLLED_WINDOW(scrolled), flowbox);

    statusLabel = gtk_label_new("");
    gtk_widget_set_halign(statusLabel, GTK_ALIGN_START);
    gtk_widget_set_margin_start(statusLabel, 10);
    gtk_widget_set_margin_bottom(statusLabel, 8);
    gtk_box_append(GTK_BOX(vbox), statusLabel);

    gtk_widget_show_all(vbox);  // GTK3: Inhalt sichtbar machen (Fenster zeigt PopupWindowWrapper)
}

void RegalWindow::rebuildTiles() {
    if (!flowbox) {
        return;
    }
    // Alte Kacheln entfernen
    GList* children = gtk_container_get_children(GTK_CONTAINER(flowbox));
    for (GList* l = children; l != nullptr; l = l->next) {
        gtk_widget_destroy(GTK_WIDGET(l->data));
    }
    g_list_free(children);

    for (auto& e : entries) {
        NotebookEntry* entry = e.get();

        GtkWidget* tile = gtk_box_new(GTK_ORIENTATION_VERTICAL, 2);
        entry->tile = tile;
        g_object_set_data(G_OBJECT(tile), "nz-entry", entry);

        // Klickbares Cover
        GtkWidget* coverBtn = gtk_button_new();
        GtkWidget* cover = gtk_drawing_area_new();
        gtk_widget_set_size_request(cover, 150, 96);
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

        // Titel + Kategorie
        GtkWidget* titleLbl = gtk_label_new(entry->title.c_str());
        gtk_label_set_max_width_chars(GTK_LABEL(titleLbl), 18);
        gtk_label_set_ellipsize(GTK_LABEL(titleLbl), PANGO_ELLIPSIZE_END);
        gtk_widget_set_tooltip_text(titleLbl, pathToString(entry->path).c_str());
        gtk_box_append(GTK_BOX(tile), titleLbl);

        // Favoriten-Zeile
        GtkWidget* favBtn = gtk_button_new_with_label(entry->favorite ? "★" : "☆");
        auto* fref = new TileRef{this, entry};
        g_object_set_data_full(G_OBJECT(favBtn), "nz-ref", fref,
                               [](gpointer p) { delete static_cast<TileRef*>(p); });
        g_signal_connect(favBtn, "clicked", G_CALLBACK(+[](GtkButton* b, gpointer d) {
                             auto* r = static_cast<TileRef*>(d);
                             r->self->toggleFavorite(r->entry);
                             gtk_button_set_label(b, r->entry->favorite ? "★" : "☆");
                         }),
                         fref);
        gtk_box_append(GTK_BOX(tile), favBtn);

        gtk_flow_box_insert(GTK_FLOW_BOX(flowbox), tile, -1);
    }

    gtk_widget_show_all(flowbox);

    if (statusLabel) {
        std::string s;
        if (folders.empty()) {
            s = _("Noch keine Ordner. „Ordner hinzufügen …“ wählen.");
        } else {
            s = std::to_string(entries.size()) + " " + _("Notizbücher/PDFs");
        }
        gtk_label_set_text(GTK_LABEL(statusLabel), s.c_str());
    }
    gtk_flow_box_invalidate_filter(GTK_FLOW_BOX(flowbox));
}

void RegalWindow::openEntry(NotebookEntry* e) {
    if (!e) {
        return;
    }
    control->openFile(e->path);
    // Fenster verzögert schließen (nicht im Klick-Handler des Kindes)
    GtkWindow* w = window.get();
    g_idle_add(+[](gpointer data) -> gboolean {
        gtk_window_close(GTK_WINDOW(data));
        return G_SOURCE_REMOVE;
    }, w);
}

void RegalWindow::toggleFavorite(NotebookEntry* e) {
    if (!e) {
        return;
    }
    e->favorite = !e->favorite;
    saveCatalog();
    gtk_flow_box_invalidate_filter(GTK_FLOW_BOX(flowbox));
}

void RegalWindow::addFolderDialog() {
    GtkWidget* dialog = gtk_file_chooser_dialog_new(
            _("Notizordner hinzufügen"), window.get(), GTK_FILE_CHOOSER_ACTION_SELECT_FOLDER, _("Abbrechen"),
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

// ---- statische Callbacks ---------------------------------------------------

void RegalWindow::onSearchChanged(GtkSearchEntry* entry, gpointer self) {
    auto* w = static_cast<RegalWindow*>(self);
    const char* t = gtk_editable_get_text(GTK_EDITABLE(entry));
    w->filterText = toLower(t ? t : "");
    gtk_flow_box_invalidate_filter(GTK_FLOW_BOX(w->flowbox));
}

void RegalWindow::onAddFolder(GtkButton*, gpointer self) { static_cast<RegalWindow*>(self)->addFolderDialog(); }

void RegalWindow::onFavToggle(GtkToggleButton* b, gpointer self) {
    auto* w = static_cast<RegalWindow*>(self);
    w->onlyFavorites = gtk_toggle_button_get_active(b);
    gtk_flow_box_invalidate_filter(GTK_FLOW_BOX(w->flowbox));
}

gboolean RegalWindow::filterFunc(GtkFlowBoxChild* child, gpointer self) {
    auto* w = static_cast<RegalWindow*>(self);
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

void RegalWindow::onCoverDraw(GtkDrawingArea*, cairo_t* cr, int width, int height, gpointer data) {
    auto* e = static_cast<NotebookEntry*>(data);
    std::uint32_t c = e ? e->color : 0x4c6557u;
    double r = ((c >> 16) & 0xff) / 255.0;
    double g = ((c >> 8) & 0xff) / 255.0;
    double b = (c & 0xff) / 255.0;
    cairo_set_source_rgb(cr, r, g, b);
    cairo_paint(cr);

    // dünner Buchrücken links
    cairo_set_source_rgba(cr, 0, 0, 0, 0.18);
    cairo_rectangle(cr, 0, 0, 8, height);
    cairo_fill(cr);

    // Kontrastfarbe für Text
    double lum = 0.299 * r + 0.587 * g + 0.114 * b;
    double tc = (lum < 0.55) ? 1.0 : 0.0;
    cairo_set_source_rgb(cr, tc, tc, tc);

    PangoLayout* layout = pango_cairo_create_layout(cr);
    pango_layout_set_width(layout, (width - 24) * PANGO_SCALE);
    pango_layout_set_wrap(layout, PANGO_WRAP_WORD_CHAR);
    pango_layout_set_ellipsize(layout, PANGO_ELLIPSIZE_END);
    pango_layout_set_height(layout, (height - 34) * PANGO_SCALE);
    PangoFontDescription* fd = pango_font_description_from_string("Sans Bold 11");
    pango_layout_set_font_description(layout, fd);
    pango_font_description_free(fd);
    pango_layout_set_text(layout, e ? e->title.c_str() : "", -1);
    cairo_move_to(cr, 16, 10);
    pango_cairo_show_layout(cr, layout);

    if (e && !e->category.empty()) {
        PangoFontDescription* fd2 = pango_font_description_from_string("Sans 8");
        pango_layout_set_font_description(layout, fd2);
        pango_font_description_free(fd2);
        pango_layout_set_height(layout, -1);
        pango_layout_set_text(layout, e->category.c_str(), -1);
        cairo_move_to(cr, 16, height - 22);
        pango_cairo_show_layout(cr, layout);
    }
    g_object_unref(layout);
}

}  // namespace xoj::notizregal
