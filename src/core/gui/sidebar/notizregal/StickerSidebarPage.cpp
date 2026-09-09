/*
 * Xournal++ – Notizregal-Fork. Siehe StickerSidebarPage.h.
 * Ziel-Toolkit GTK3 (gtk4_helper-Shims). Kompiliert wird über die CI.
 *
 * @license GNU GPLv2 or later
 */
#include "StickerSidebarPage.h"

#include <algorithm>
#include <cctype>
#include <fstream>
#include <string>

#include "control/Control.h"
#include "control/tools/ImageHandler.h"
#include "gui/GladeSearchpath.h"
#include "model/Image.h"
#include "model/PageRef.h"
#include "util/gtk4_helper.h"
#include "util/i18n.h"

namespace xoj::notizregal {

namespace {
constexpr int MAX_TILES = 150;  // max. gleichzeitig gerenderte Sticker
constexpr int TILE_PX = 44;

struct StickerRef {
    StickerSidebarPage* self;
    std::string file;
};

std::string toLower(std::string s) {
    std::transform(s.begin(), s.end(), s.begin(), [](unsigned char c) { return static_cast<char>(std::tolower(c)); });
    return s;
}
}  // namespace

StickerSidebarPage::StickerSidebarPage(Control* control): AbstractSidebarPage(control) {
    openmojiDir = fs::weakly_canonical(control->getGladeSearchPath()->getFirstSearchPath() / ".." / "notizregal" /
                                       "app" / "OpenMoji");
    buildUi();
}

StickerSidebarPage::~StickerSidebarPage() = default;

std::string StickerSidebarPage::getName() { return _("Sticker"); }
std::string StickerSidebarPage::getIconName() { return "xopp-sticker"; }
bool StickerSidebarPage::hasData() { return true; }
GtkWidget* StickerSidebarPage::getWidget() { return root; }
void StickerSidebarPage::layout() {}
void StickerSidebarPage::disableSidebar() {}

void StickerSidebarPage::enableSidebar() {
    if (!loaded) {
        loadIndex();
        loaded = true;
        populate();
    }
}

void StickerSidebarPage::loadIndex() {
    items.clear();
    fs::path idx = openmojiDir / "sticker-index.tsv";
    std::ifstream in(idx, std::ios::binary);
    if (!in) {
        return;
    }
    std::string line;
    while (std::getline(in, line)) {
        if (!line.empty() && line.back() == '\r') {
            line.pop_back();
        }
        if (line.empty()) {
            continue;
        }
        // file \t name \t category \t tags
        auto t1 = line.find('\t');
        if (t1 == std::string::npos) {
            continue;
        }
        auto t2 = line.find('\t', t1 + 1);
        auto t3 = (t2 == std::string::npos) ? std::string::npos : line.find('\t', t2 + 1);
        StickerItem it;
        it.file = line.substr(0, t1);
        it.name = (t2 == std::string::npos) ? line.substr(t1 + 1) : line.substr(t1 + 1, t2 - t1 - 1);
        it.category = (t2 == std::string::npos) ? std::string()
                      : (t3 == std::string::npos) ? line.substr(t2 + 1)
                                                  : line.substr(t2 + 1, t3 - t2 - 1);
        std::string tags = (t3 == std::string::npos) ? std::string() : line.substr(t3 + 1);
        it.hay = toLower(it.name + " " + it.category + " " + tags);
        items.push_back(std::move(it));
    }
}

void StickerSidebarPage::buildUi() {
    root = gtk_box_new(GTK_ORIENTATION_VERTICAL, 6);

    searchEntry = gtk_search_entry_new();
    gtk_widget_set_margin_start(searchEntry, 6);
    gtk_widget_set_margin_end(searchEntry, 6);
    gtk_widget_set_margin_top(searchEntry, 6);
    g_signal_connect(searchEntry, "search-changed", G_CALLBACK(onSearchChanged), this);
    gtk_box_append(GTK_BOX(root), searchEntry);

    GtkWidget* scrolled = gtk_scrolled_window_new();
    gtk_widget_set_vexpand(scrolled, TRUE);
    gtk_box_append(GTK_BOX(root), scrolled);

    flowbox = gtk_flow_box_new();
    gtk_flow_box_set_selection_mode(GTK_FLOW_BOX(flowbox), GTK_SELECTION_NONE);
    gtk_flow_box_set_homogeneous(GTK_FLOW_BOX(flowbox), TRUE);
    gtk_flow_box_set_max_children_per_line(GTK_FLOW_BOX(flowbox), 12);
    gtk_flow_box_set_row_spacing(GTK_FLOW_BOX(flowbox), 4);
    gtk_flow_box_set_column_spacing(GTK_FLOW_BOX(flowbox), 4);
    gtk_widget_set_margin_start(flowbox, 6);
    gtk_widget_set_margin_end(flowbox, 6);
    gtk_scrolled_window_set_child(GTK_SCROLLED_WINDOW(scrolled), flowbox);

    statusLabel = gtk_label_new("");
    gtk_widget_set_halign(statusLabel, GTK_ALIGN_START);
    gtk_widget_set_margin_start(statusLabel, 6);
    gtk_widget_set_margin_bottom(statusLabel, 4);
    gtk_box_append(GTK_BOX(root), statusLabel);

    gtk_widget_show_all(root);
}

void StickerSidebarPage::populate() {
    if (!flowbox) {
        return;
    }
    GList* children = gtk_container_get_children(GTK_CONTAINER(flowbox));
    for (GList* l = children; l != nullptr; l = l->next) {
        gtk_widget_destroy(GTK_WIDGET(l->data));
    }
    g_list_free(children);

    int shown = 0;
    int matches = 0;
    for (const auto& it: items) {
        if (!filterText.empty() && it.hay.find(filterText) == std::string::npos) {
            continue;
        }
        matches++;
        if (shown >= MAX_TILES) {
            continue;
        }
        fs::path p = openmojiDir / it.file;
        std::string ps;
        try {
            ps = p.string();
        } catch (...) {
            continue;
        }
        GdkPixbuf* pb = gdk_pixbuf_new_from_file_at_scale(ps.c_str(), TILE_PX, TILE_PX, TRUE, nullptr);
        if (!pb) {
            continue;
        }
        GtkWidget* image = gtk_image_new_from_pixbuf(pb);
        g_object_unref(pb);

        GtkWidget* btn = gtk_button_new();
        gtk_button_set_child(GTK_BUTTON(btn), image);
        gtk_widget_set_tooltip_text(btn, it.name.c_str());

        auto* ref = new StickerRef{this, it.file};
        g_object_set_data_full(G_OBJECT(btn), "nz-sticker", ref,
                               [](gpointer d) { delete static_cast<StickerRef*>(d); });
        g_signal_connect(btn, "clicked", G_CALLBACK(+[](GtkButton*, gpointer d) {
                             auto* r = static_cast<StickerRef*>(d);
                             r->self->insertSticker(r->file);
                         }),
                         ref);

        gtk_flow_box_insert(GTK_FLOW_BOX(flowbox), btn, -1);
        shown++;
    }
    gtk_widget_show_all(flowbox);

    if (statusLabel) {
        std::string s;
        if (items.empty()) {
            s = _("Sticker-Paket nicht gefunden.");
        } else if (matches > shown) {
            s = std::to_string(shown) + " / " + std::to_string(matches) + " " + _("(eingrenzen …)");
        } else {
            s = std::to_string(matches) + " " + _("Sticker");
        }
        gtk_label_set_text(GTK_LABEL(statusLabel), s.c_str());
    }
}

void StickerSidebarPage::insertSticker(const std::string& file) {
    fs::path p = openmojiDir / file;
    auto img = ImageHandler::createImageFromFile(p);
    if (!img) {
        return;  // createImageFromFile meldet Fehler selbst
    }
    PageRef page = control->getCurrentPage();
    if (!page) {
        return;
    }
    auto [w, h] = img->getImageSize();
    if (w <= 0 || h <= 0) {
        return;
    }
    const double target = 64.0;  // Zielkantenlänge in pt
    double scale = target / static_cast<double>(std::max(w, h));
    img->setOrigin(96.0, 96.0);
    img->setWidth(w * scale);
    img->setHeight(h * scale);
    ImageHandler::addImageToDocument(std::move(img), page, control, true);
}

void StickerSidebarPage::onSearchChanged(GtkSearchEntry* entry, gpointer self) {
    auto* w = static_cast<StickerSidebarPage*>(self);
    const char* t = gtk_editable_get_text(GTK_EDITABLE(entry));
    w->filterText = toLower(t ? t : "");
    w->populate();
}

}  // namespace xoj::notizregal
