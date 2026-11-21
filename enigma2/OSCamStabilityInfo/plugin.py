# -*- coding: utf-8 -*-
"""Read-only OSCam Stability status screen for Enigma2 / OpenATV."""
import os
import time

from enigma import eTimer
from Components.ActionMap import ActionMap
from Components.ScrollLabel import ScrollLabel
from Components.Sources.StaticText import StaticText
from Plugins.Plugin import PluginDescriptor
from Screens.Screen import Screen

PID_FILE = "/var/run/oscam-stability/oscam.pid"
BIN_DIR = "/usr/lib/oscam-stability"
ECM_FILE = "/tmp/ecm.info"
VERSION_FILE = "/usr/share/oscam-stability/version"
INIT_SCRIPT = "/etc/init.d/softcam.oscam-stability"


def running_pid():
    try:
        with open(PID_FILE, "r") as handle:
            pid = int(handle.read().strip())
        executable = os.path.realpath("/proc/%d/exe" % pid)
        if executable in (
            BIN_DIR + "/oscam-arm",
            BIN_DIR + "/oscam-aarch64",
        ):
            return pid
    except (OSError, ValueError):
        pass
    return None


def current_softcam():
    try:
        target = os.readlink("/etc/init.d/softcam")
        return os.path.basename(target)
    except OSError:
        return "not selected"


def package_version():
    try:
        with open(VERSION_FILE, "r") as handle:
            return handle.read(100).strip() or "unknown"
    except OSError:
        return "unknown"


def ecm_summary():
    try:
        age = time.time() - os.path.getmtime(ECM_FILE)
        if age > 60:
            return "ECM: no recent data (last update %d s ago)" % int(age)
        allowed = ("ecm time", "caid", "provid", "provider", "system", "hops", "pid")
        result = []
        with open(ECM_FILE, "r") as handle:
            for line in handle:
                if ":" not in line:
                    continue
                key, value = line.split(":", 1)
                if key.strip().lower() in allowed:
                    result.append("%s: %s" % (key.strip(), value.strip()[:60]))
                if len(result) >= 8:
                    break
        return "\n".join(result) if result else "ECM: no supported fields in /tmp/ecm.info"
    except OSError:
        return "ECM: /tmp/ecm.info not available"


class OSCamStabilityInfo(Screen):
    skin = """
    <screen name="OSCamStabilityInfo" position="center,center" size="820,520" title="OSCam Stability Info">
        <widget name="info" position="20,20" size="780,425" font="Regular;24" />
        <widget name="key_red" position="20,470" size="160,30" font="Regular;22" foregroundColor="#ff6060" />
        <widget name="key_green" position="230,470" size="240,30" font="Regular;22" foregroundColor="#70e070" />
    </screen>
    """

    def __init__(self, session):
        Screen.__init__(self, session)
        self["info"] = ScrollLabel("")
        self["key_red"] = StaticText("Close")
        self["key_green"] = StaticText("Refresh")
        self["actions"] = ActionMap(
            ["OkCancelActions", "ColorActions", "DirectionActions"],
            {
                "cancel": self.close,
                "ok": self.refresh,
                "red": self.close,
                "green": self.refresh,
                "up": self["info"].pageUp,
                "down": self["info"].pageDown,
            },
            -1,
        )
        self.timer = eTimer()
        self.timer.callback.append(self.refresh)
        self.onLayoutFinish.append(self.refresh)
        self.onClose.append(self.cleanup)

    def refresh(self):
        pid = running_pid()
        selected = current_softcam()
        active = selected == "softcam.oscam-stability"
        lines = [
            "OSCam Stability | Enigma2",
            "",
            "Package version: %s" % package_version(),
            "Process: %s" % ("RUNNING (PID %d)" % pid if pid else "STOPPED / NOT DETECTED"),
            "Selected in OpenATV: %s" % ("YES" if active else "NO"),
            "Selected softcam: %s" % selected,
            "",
        ]
        if pid and not active:
            lines.append("Note: manually started; select oscam-stability in Softcam Settings.")
            lines.append("")
        lines.extend([
            ecm_summary(),
            "",
            "OpenATV: Menu > Setup > Decryption & Parental Control > Softcam Settings",
            "WebIF: use the port configured in your own oscam.conf",
        ])
        self["info"].setText("\n".join(lines))
        self.timer.start(5000, True)

    def cleanup(self):
        self.timer.stop()


def open_info(session, **kwargs):
    session.open(OSCamStabilityInfo)


def Plugins(**kwargs):
    return [
        PluginDescriptor(
            name="OSCam Stability Info",
            description="Local OSCam Stability status and ECM diagnostics",
            where=PluginDescriptor.WHERE_PLUGINMENU,
            fnc=open_info,
        ),
        PluginDescriptor(
            name="OSCam Stability Info",
            description="Local OSCam Stability status and ECM diagnostics",
            where=PluginDescriptor.WHERE_EXTENSIONSMENU,
            fnc=open_info,
        ),
    ]
