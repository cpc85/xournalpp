/*
 * Xournal++ – Notizregal-Fork
 *
 * OpenMoji-Sticker als andockbarer Sidebar-Reiter: durchsuchbares Bildraster;
 * Klick fügt den Sticker als Bild in die aktuelle Seite ein. Bilder liegen unter
 * share/xournalpp/notizregal/app/OpenMoji (Index: sticker-index.tsv).
 *
 * @license GNU GPLv2 or later
 */
#pragma once

#include <string>
#include <vector>

#include <gtk/gtk.h>

#include "filesystem.h"
#include "gui/sidebar/AbstractSidebarPage.h"

class Control;

namespace xoj::notizregal {

struct StickerItem {
    std::string file;      // relativ zum OpenMoji-Ordner, z. B. "png/1F600.png"
    std::string name;      // Anzeigename
    std::string category;  // Kategorie
    std::string hay;       // vorbereiteter Suchtext (klein)
};

class StickerSidebarPage: public AbstractSidebarPage {
public:
    explicit StickerSidebarPage(Control* control);
    ~StickerSidebarPage() override;

    void enableSidebar() override;
    void disableSidebar() override;
    void layout() override;
    std::string getName() override;
    std::string getIconName() override;
    bool hasData() override;
    GtkWidget* getWidget() override;

private:
    void buildUi();
    void loadIndex();
    void populate();
    void insertSticker(const std::string& file);

    static void onSearchChanged(GtkSearchEntry* entry, gpointer self);

    fs::path openmojiDir;
    GtkWidget* root = nullptr;
    GtkWidget* searchEntry = nullptr;
    GtkWidget* flowbox = nullptr;
    GtkWidget* statusLabel = nullptr;

    std::vector<StickerItem> items;
    std::string filterText;
    bool loaded = false;
};

}  // namespace xoj::notizregal
