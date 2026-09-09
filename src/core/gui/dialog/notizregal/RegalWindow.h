/*
 * Xournal++ – Notizregal-Fork
 *
 * Natives Notizbuchregal: ein GTK-Fenster mit Cover-Kacheln, Suche,
 * Favoriten-Filter und „Ordner hinzufügen“. Ersetzt die frühere
 * PowerShell/WPF-Variante. Metadaten liegen als GKeyFile im Konfig-Ordner.
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
#include "util/raii/GtkWindowUPtr.h"

class Control;

namespace xoj::notizregal {

struct NotebookEntry {
    fs::path path;
    std::string title;
    std::string category;
    std::uint32_t color = 0x4c6557u;  // Cover-Farbe (RGB)
    bool favorite = false;
    bool isPdf = false;
    GtkWidget* tile = nullptr;  // Kachelinhalt (Kind des GtkFlowBoxChild)
};

class RegalWindow {
public:
    explicit RegalWindow(Control* control);
    ~RegalWindow();
    RegalWindow(const RegalWindow&) = delete;
    RegalWindow& operator=(const RegalWindow&) = delete;

    inline GtkWindow* getWindow() const { return window.get(); }

private:
    void buildUi();
    void loadCatalog();
    void scanFolders();
    void rebuildTiles();
    void saveCatalog();
    void addFolderDialog();
    void openEntry(NotebookEntry* e);
    void toggleFavorite(NotebookEntry* e);

    fs::path catalogFile() const;
    static std::uint32_t defaultColorFor(const std::string& title);

    // GTK-Callbacks (statisch -> Instanz über user_data)
    static void onSearchChanged(GtkSearchEntry* entry, gpointer self);
    static void onAddFolder(GtkButton* b, gpointer self);
    static void onFavToggle(GtkToggleButton* b, gpointer self);
    static gboolean filterFunc(GtkFlowBoxChild* child, gpointer self);
    static void onCoverDraw(GtkDrawingArea* area, cairo_t* cr, int width, int height, gpointer entry);

    Control* control;

    GtkWidget* flowbox = nullptr;
    GtkWidget* searchEntry = nullptr;
    GtkWidget* favToggle = nullptr;
    GtkWidget* statusLabel = nullptr;

    std::vector<fs::path> folders;
    std::vector<std::unique_ptr<NotebookEntry>> entries;
    std::string filterText;
    bool onlyFavorites = false;

    // window zuletzt: wird im Destruktor zuerst zerstört (vor entries).
    xoj::util::GtkWindowUPtr window;
};

}  // namespace xoj::notizregal
