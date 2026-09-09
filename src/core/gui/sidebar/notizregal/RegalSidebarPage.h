/*
 * Xournal++ – Notizregal-Fork
 *
 * Notizbuchregal als andockbarer Sidebar-Reiter (wie Index/Seitenvorschau).
 * Cover-Kacheln, Suche, Favoriten-Filter, „Ordner hinzufügen“. Klick öffnet das
 * Notizbuch im Editor. Metadaten als GKeyFile im Konfig-Ordner.
 *
 * @license GNU GPLv2 or later
 */
#pragma once

#include <cstdint>
#include <memory>
#include <string>
#include <vector>

#include <gtk/gtk.h>

#include "filesystem.h"
#include "gui/sidebar/AbstractSidebarPage.h"

class Control;

namespace xoj::notizregal {

struct NotebookEntry {
    fs::path path;
    std::string title;
    std::string category;
    std::uint32_t color = 0x4c6557u;
    bool favorite = false;
    bool isPdf = false;
    GtkWidget* tile = nullptr;
};

class RegalSidebarPage: public AbstractSidebarPage {
public:
    explicit RegalSidebarPage(Control* control);
    ~RegalSidebarPage() override;

    // AbstractSidebarPage
    void enableSidebar() override;
    void disableSidebar() override;
    void layout() override;
    std::string getName() override;
    std::string getIconName() override;
    bool hasData() override;
    GtkWidget* getWidget() override;

private:
    void buildUi();
    void loadCatalog();
    void scanFolders();
    void rebuildTiles();
    void saveCatalog();
    void addFolderDialog();
    void openEntry(NotebookEntry* e);
    void toggleFavorite(NotebookEntry* e);
    void editEntry(NotebookEntry* e);
    void refresh();
    void newNotebook();

    fs::path catalogFile() const;
    static std::uint32_t defaultColorFor(const std::string& title);

    static void onSearchChanged(GtkSearchEntry* entry, gpointer self);
    static void onAddFolder(GtkButton* b, gpointer self);
    static void onFavToggle(GtkToggleButton* b, gpointer self);
    static void onRefresh(GtkButton* b, gpointer self);
    static void onNew(GtkButton* b, gpointer self);
    static gboolean filterFunc(GtkFlowBoxChild* child, gpointer self);
    static void onCoverDraw(GtkDrawingArea* area, cairo_t* cr, int width, int height, gpointer entry);

    GtkWidget* root = nullptr;
    GtkWidget* flowbox = nullptr;
    GtkWidget* searchEntry = nullptr;
    GtkWidget* favToggle = nullptr;
    GtkWidget* statusLabel = nullptr;

    std::vector<fs::path> folders;
    std::vector<std::unique_ptr<NotebookEntry>> entries;
    std::string filterText;
    bool onlyFavorites = false;
    bool scanned = false;
};

}  // namespace xoj::notizregal
