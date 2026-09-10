/*
 * Xournal++ – Notizregal-Fork. Siehe NotebookVersioning.h.
 *
 * @license GNU GPLv2 or later
 */
#include "NotebookVersioning.h"

#include <algorithm>
#include <cctype>
#include <ctime>
#include <fstream>

#include <glib.h>

#include "util/PathUtil.h"

namespace xoj::notizregal {

namespace {
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

std::string nowIso() {
    std::time_t t = std::time(nullptr);
    char buf[32];
    std::tm tmv{};
#ifdef _WIN32
    localtime_s(&tmv, &t);
#else
    localtime_r(&t, &tmv);
#endif
    std::strftime(buf, sizeof(buf), "%Y-%m-%dT%H:%M:%S", &tmv);
    return buf;
}

std::string bookKey(const fs::path& book) {
    std::error_code ec;
    fs::path full = fs::weakly_canonical(book, ec);
    std::string s = toLower(pathToString(full.empty() ? book : full));
    gchar* sum = g_compute_checksum_for_string(G_CHECKSUM_SHA256, s.c_str(), static_cast<gssize>(s.size()));
    std::string key = sum ? sum : "0";
    if (sum) {
        g_free(sum);
    }
    return key;
}
}  // namespace

fs::path NotebookVersioning::versionDir(const fs::path& book) {
    fs::path dir = Util::getConfigSubfolder("notizregal") / "versionen" / bookKey(book);
    std::error_code ec;
    fs::create_directories(dir, ec);
    return dir;
}

fs::path NotebookVersioning::indexFile(const fs::path& book) { return versionDir(book) / "index.ini"; }

std::string NotebookVersioning::fileSha256(const fs::path& p) {
    std::ifstream in(p, std::ios::binary);
    if (!in) {
        return {};
    }
    GChecksum* cs = g_checksum_new(G_CHECKSUM_SHA256);
    char buf[65536];
    while (in) {
        in.read(buf, sizeof(buf));
        std::streamsize n = in.gcount();
        if (n > 0) {
            g_checksum_update(cs, reinterpret_cast<const guchar*>(buf), static_cast<gssize>(n));
        }
    }
    std::string result = g_checksum_get_string(cs);
    g_checksum_free(cs);
    return result;
}

std::vector<VersionEntry> NotebookVersioning::listVersions(const fs::path& book) {
    std::vector<VersionEntry> out;
    std::string idx = pathToString(indexFile(book));
    GKeyFile* kf = g_key_file_new();
    if (g_key_file_load_from_file(kf, idx.c_str(), G_KEY_FILE_NONE, nullptr)) {
        gsize n = 0;
        gchar** groups = g_key_file_get_groups(kf, &n);
        for (gsize i = 0; i < n; i++) {
            if (!g_str_has_prefix(groups[i], "v-")) {
                continue;
            }
            VersionEntry e;
            e.id = std::string(groups[i] + 2);
            gchar* h = g_key_file_get_string(kf, groups[i], "hash", nullptr);
            e.hash = h ? h : "";
            g_free(h);
            gchar* c = g_key_file_get_string(kf, groups[i], "created", nullptr);
            e.created = c ? c : "";
            g_free(c);
            gchar* r = g_key_file_get_string(kf, groups[i], "reason", nullptr);
            e.reason = r ? r : "";
            g_free(r);
            e.size = static_cast<std::uintmax_t>(g_key_file_get_uint64(kf, groups[i], "size", nullptr));
            out.push_back(std::move(e));
        }
        g_strfreev(groups);
    }
    g_key_file_free(kf);
    // Neueste zuerst (created ist ISO -> lexikografisch sortierbar).
    std::sort(out.begin(), out.end(), [](const VersionEntry& a, const VersionEntry& b) { return a.created > b.created; });
    return out;
}

bool NotebookVersioning::saveVersion(const fs::path& book, const std::string& reason) {
    std::error_code ec;
    if (!fs::exists(book, ec)) {
        return false;
    }
    std::string hash = fileSha256(book);
    if (hash.empty()) {
        return false;
    }
    auto existing = listVersions(book);
    if (!existing.empty() && existing.front().hash == hash) {
        return false;  // unveraendert seit letzter Sicherung
    }
    fs::path dir = versionDir(book);
    fs::path blob = dir / (hash + ".xopp");
    if (!fs::exists(blob, ec)) {
        fs::copy_file(book, blob, fs::copy_options::overwrite_existing, ec);
        if (ec) {
            return false;
        }
    }
    gchar* uuid = g_uuid_string_random();
    std::string id = uuid ? uuid : hash;
    if (uuid) {
        g_free(uuid);
    }

    std::string idx = pathToString(indexFile(book));
    GKeyFile* kf = g_key_file_new();
    g_key_file_load_from_file(kf, idx.c_str(), G_KEY_FILE_NONE, nullptr);
    g_key_file_set_string(kf, "meta", "book", pathToString(book).c_str());
    std::string group = "v-" + id;
    g_key_file_set_string(kf, group.c_str(), "hash", hash.c_str());
    g_key_file_set_string(kf, group.c_str(), "created", nowIso().c_str());
    g_key_file_set_string(kf, group.c_str(), "reason", reason.c_str());
    g_key_file_set_uint64(kf, group.c_str(), "size", static_cast<guint64>(fs::file_size(book, ec)));
    g_key_file_save_to_file(kf, idx.c_str(), nullptr);
    g_key_file_free(kf);
    return true;
}

bool NotebookVersioning::restoreVersion(const fs::path& book, const std::string& id, std::string& outSafety,
                                        std::string& outError) {
    auto versions = listVersions(book);
    const VersionEntry* found = nullptr;
    for (const auto& v: versions) {
        if (v.id == id) {
            found = &v;
            break;
        }
    }
    if (!found) {
        outError = "Version nicht gefunden.";
        return false;
    }
    fs::path dir = versionDir(book);
    fs::path blob = dir / (found->hash + ".xopp");
    std::error_code ec;
    if (!fs::exists(blob, ec)) {
        outError = "Gesicherte Version fehlt auf der Festplatte.";
        return false;
    }
    // Aktuellen Stand vorher sichern (als Version und als Sicherungskopie).
    if (fs::exists(book, ec)) {
        saveVersion(book, "Vor Wiederherstellung");
        fs::path safety = dir / ("vor-wiederherstellung-" + fileSha256(book) + ".xopp");
        fs::copy_file(book, safety, fs::copy_options::overwrite_existing, ec);
        outSafety = pathToString(safety);
    }
    fs::copy_file(blob, book, fs::copy_options::overwrite_existing, ec);
    if (ec) {
        outError = "Datei konnte nicht ersetzt werden: " + ec.message();
        return false;
    }
    saveVersion(book, "Wiederhergestellt");
    return true;
}

bool NotebookVersioning::exportVersion(const fs::path& book, const std::string& id, const fs::path& dest,
                                       std::string& outError) {
    auto versions = listVersions(book);
    const VersionEntry* found = nullptr;
    for (const auto& v: versions) {
        if (v.id == id) {
            found = &v;
            break;
        }
    }
    if (!found) {
        outError = "Version nicht gefunden.";
        return false;
    }
    fs::path blob = versionDir(book) / (found->hash + ".xopp");
    std::error_code ec;
    if (!fs::exists(blob, ec)) {
        outError = "Gesicherte Version fehlt auf der Festplatte.";
        return false;
    }
    fs::copy_file(blob, dest, fs::copy_options::overwrite_existing, ec);
    if (ec) {
        outError = "Export fehlgeschlagen: " + ec.message();
        return false;
    }
    return true;
}

}  // namespace xoj::notizregal
