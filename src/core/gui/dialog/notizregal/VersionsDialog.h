/*
 * Xournal++ – Notizregal-Fork
 *
 * Modaler Dialog zur Versionsverwaltung des aktuellen Notizbuchs:
 * auflisten, jetzt sichern, wiederherstellen, als Kopie exportieren.
 *
 * @license GNU GPLv2 or later
 */
#pragma once

#include "filesystem.h"

class Control;

namespace xoj::notizregal {

void showVersionsDialog(Control* control, const fs::path& book);

}  // namespace xoj::notizregal
