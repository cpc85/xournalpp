/*
 * Xournal++ – Notizregal-Fork
 *
 * Versionsverwaltung fuer .xopp-Notizbuecher (nativ, ohne externe Werkzeuge):
 * manuelles Sichern, Auflisten, Wiederherstellen und Exportieren aelterer
 * Staende. Kopien + Index liegen unter <config>/notizregal/versionen/<key>.
 *
 * @license GNU GPLv2 or later
 */
#pragma once

#include <cstdint>
#include <string>
#include <vector>

#include "filesystem.h"

namespace xoj::notizregal {

struct VersionEntry {
    std::string id;
    std::string hash;
    std::string created;  // ISO-8601
    std::string reason;
    std::uintmax_t size = 0;
};

class NotebookVersioning {
public:
    /// Sichert den aktuellen Stand; gibt false zurueck, wenn identisch zum letzten.
    static bool saveVersion(const fs::path& book, const std::string& reason);

    /// Alle Versionen, neueste zuerst.
    static std::vector<VersionEntry> listVersions(const fs::path& book);

    /// Stellt die Version wieder her; sichert vorher den aktuellen Stand.
    /// Bei Erfolg true; outSafety = Pfad der Sicherung, outError sonst gesetzt.
    static bool restoreVersion(const fs::path& book, const std::string& id, std::string& outSafety,
                               std::string& outError);

    /// Exportiert die Version als Kopie nach dest.
    static bool exportVersion(const fs::path& book, const std::string& id, const fs::path& dest, std::string& outError);

private:
    static fs::path versionDir(const fs::path& book);
    static fs::path indexFile(const fs::path& book);
    static std::string fileSha256(const fs::path& p);
};

}  // namespace xoj::notizregal
