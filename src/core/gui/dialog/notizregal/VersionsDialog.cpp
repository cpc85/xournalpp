/*
 * Xournal++ – Notizregal-Fork. Siehe VersionsDialog.h.
 * Ziel-Toolkit GTK3 (gtk4_helper-Shims). Kompiliert wird über die CI.
 *
 * @license GNU GPLv2 or later
 */
#include "VersionsDialog.h"

#include <algorithm>
#include <string>
#include <vector>

#include <gtk/gtk.h>

#include "control/Control.h"
#include "control/notizregal/NotebookVersioning.h"
#include "util/gtk4_helper.h"
#include "util/i18n.h"

namespace xoj::notizregal {

namespace {
enum { RESP_SAVE = 1, RESP_RESTORE = 2, RESP_EXPORT = 3 };

void populate(GtkListBox* lb, const fs::path& book) {
    GList* ch = gtk_container_get_children(GTK_CONTAINER(lb));
    for (GList* l = ch; l != nullptr; l = l->next) {
        gtk_widget_destroy(GTK_WIDGET(l->data));
    }
    g_list_free(ch);

    for (const auto& v: NotebookVersioning::listVersions(book)) {
        std::string created = v.created;
        std::replace(created.begin(), created.end(), 'T', ' ');
        std::string label = created + "   —   " + v.reason + "   (" + std::to_string(v.size / 1024) + " KB)";

        GtkWidget* row = gtk_list_box_row_new();
        GtkWidget* lbl = gtk_label_new(label.c_str());
        gtk_widget_set_halign(lbl, GTK_ALIGN_START);
        gtk_widget_set_margin_start(lbl, 8);
        gtk_widget_set_margin_end(lbl, 8);
        gtk_widget_set_margin_top(lbl, 4);
        gtk_widget_set_margin_bottom(lbl, 4);
        gtk_list_box_row_set_child(GTK_LIST_BOX_ROW(row), lbl);
        g_object_set_data_full(G_OBJECT(row), "nz-id", g_strdup(v.id.c_str()), g_free);
        gtk_list_box_append(lb, row);
    }
    gtk_widget_show_all(GTK_WIDGET(lb));
}

void info(GtkWindow* parent, const std::string& msg) {
    GtkWidget* d = gtk_message_dialog_new(parent, GTK_DIALOG_MODAL, GTK_MESSAGE_INFO, GTK_BUTTONS_OK, "%s",
                                          msg.c_str());
    gtk_dialog_run(GTK_DIALOG(d));
    gtk_widget_destroy(d);
}

std::string selectedId(GtkListBox* lb) {
    GtkListBoxRow* row = gtk_list_box_get_selected_row(lb);
    if (!row) {
        return {};
    }
    auto* id = static_cast<const char*>(g_object_get_data(G_OBJECT(row), "nz-id"));
    return id ? std::string(id) : std::string();
}
}  // namespace

void showVersionsDialog(Control* control, const fs::path& book) {
    GtkWidget* dlg = gtk_dialog_new_with_buttons(
            _("Versionen"), control->getGtkWindow(),
            static_cast<GtkDialogFlags>(GTK_DIALOG_MODAL | GTK_DIALOG_DESTROY_WITH_PARENT), nullptr, nullptr);
    gtk_window_set_default_size(GTK_WINDOW(dlg), 480, 480);
    gtk_dialog_add_button(GTK_DIALOG(dlg), _("Jetzt sichern"), RESP_SAVE);
    gtk_dialog_add_button(GTK_DIALOG(dlg), _("Wiederherstellen"), RESP_RESTORE);
    gtk_dialog_add_button(GTK_DIALOG(dlg), _("Als Kopie exportieren"), RESP_EXPORT);
    gtk_dialog_add_button(GTK_DIALOG(dlg), _("Schließen"), GTK_RESPONSE_CLOSE);

    GtkWidget* content = gtk_dialog_get_content_area(GTK_DIALOG(dlg));
    GtkWidget* hint = gtk_label_new(_("Automatische Sicherung bei jedem Speichern. Version auswählen:"));
    gtk_widget_set_halign(hint, GTK_ALIGN_START);
    gtk_widget_set_margin_start(hint, 8);
    gtk_widget_set_margin_top(hint, 8);
    gtk_box_append(GTK_BOX(content), hint);

    GtkWidget* scrolled = gtk_scrolled_window_new();
    gtk_widget_set_vexpand(scrolled, TRUE);
    gtk_widget_set_hexpand(scrolled, TRUE);
    GtkWidget* listbox = gtk_list_box_new();
    gtk_list_box_set_selection_mode(GTK_LIST_BOX(listbox), GTK_SELECTION_SINGLE);
    gtk_scrolled_window_set_child(GTK_SCROLLED_WINDOW(scrolled), listbox);
    gtk_box_append(GTK_BOX(content), scrolled);

    populate(GTK_LIST_BOX(listbox), book);
    gtk_widget_show_all(dlg);

    bool loop = true;
    while (loop) {
        int resp = gtk_dialog_run(GTK_DIALOG(dlg));
        switch (resp) {
            case RESP_SAVE: {
                bool created = NotebookVersioning::saveVersion(book, "Manuell");
                populate(GTK_LIST_BOX(listbox), book);
                if (!created) {
                    info(GTK_WINDOW(dlg), _("Keine Änderung seit der letzten Sicherung."));
                }
                break;
            }
            case RESP_EXPORT: {
                std::string id = selectedId(GTK_LIST_BOX(listbox));
                if (id.empty()) {
                    info(GTK_WINDOW(dlg), _("Bitte zuerst eine Version auswählen."));
                    break;
                }
                GtkWidget* save = gtk_file_chooser_dialog_new(
                        _("Version exportieren"), GTK_WINDOW(dlg), GTK_FILE_CHOOSER_ACTION_SAVE, _("Abbrechen"),
                        GTK_RESPONSE_CANCEL, _("Speichern"), GTK_RESPONSE_ACCEPT, nullptr);
                std::string suggested = book.stem().string() + "-version.xopp";
                gtk_file_chooser_set_current_name(GTK_FILE_CHOOSER(save), suggested.c_str());
                if (gtk_dialog_run(GTK_DIALOG(save)) == GTK_RESPONSE_ACCEPT) {
                    gchar* name = gtk_file_chooser_get_filename(GTK_FILE_CHOOSER(save));
                    if (name) {
                        std::string err;
                        bool ok = NotebookVersioning::exportVersion(book, id, fs::path(name), err);
                        g_free(name);
                        info(GTK_WINDOW(dlg), ok ? _("Version als Kopie gespeichert.") : err);
                    }
                }
                gtk_widget_destroy(save);
                break;
            }
            case RESP_RESTORE: {
                std::string id = selectedId(GTK_LIST_BOX(listbox));
                if (id.empty()) {
                    info(GTK_WINDOW(dlg), _("Bitte zuerst eine Version auswählen."));
                    break;
                }
                GtkWidget* ask = gtk_message_dialog_new(
                        GTK_WINDOW(dlg), GTK_DIALOG_MODAL, GTK_MESSAGE_QUESTION, GTK_BUTTONS_YES_NO, "%s",
                        _("Diese Version wiederherstellen? Der aktuelle Stand wird vorher gesichert."));
                int a = gtk_dialog_run(GTK_DIALOG(ask));
                gtk_widget_destroy(ask);
                if (a == GTK_RESPONSE_YES) {
                    std::string safety;
                    std::string err;
                    bool ok = NotebookVersioning::restoreVersion(book, id, safety, err);
                    populate(GTK_LIST_BOX(listbox), book);
                    if (ok) {
                        info(GTK_WINDOW(dlg),
                             std::string(_("Version wiederhergestellt. Sicherung des vorherigen Stands:\n")) + safety);
                        // Datei neu laden, damit der wiederhergestellte Stand sichtbar wird.
                        control->openFile(book);
                        loop = false;
                    } else {
                        info(GTK_WINDOW(dlg), err);
                    }
                }
                break;
            }
            default:  // GTK_RESPONSE_CLOSE / DELETE_EVENT
                loop = false;
                break;
        }
    }
    gtk_widget_destroy(dlg);
}

}  // namespace xoj::notizregal
