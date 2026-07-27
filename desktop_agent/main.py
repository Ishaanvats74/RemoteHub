from PySide6.QtWidgets import QApplication,QMenu,QStyle,QSystemTrayIcon,QMessageBox
from desktop_agent.controller.agent_controller import AgentController
from PySide6.QtGui import QIcon, QAction
from ui.main_window import MainWindow
from qasync import QEventLoop
import asyncio
import sys



app = QApplication(sys.argv)
app.setQuitOnLastWindowClosed(False)

# ---------------- Main Window ----------------

window = MainWindow()
controller = AgentController(window)

# UI -> Controller
window.pair_page.pair_requested.connect(controller.pair_device)
window.connected_page.disconnect_requested.connect(controller.disconnect)

# Controller -> UI
controller.show_pair.connect(window.show_pair_page)
controller.show_connected.connect(window.show_connected_page)

controller.error.connect(lambda message: QMessageBox.warning(window,"RemoteHub",message))

window.show()

# ---------------- Tray Icon ----------------

style = app.style()
icon = QIcon(style.standardIcon(QStyle.StandardPixmap.SP_ComputerIcon))

tray = QSystemTrayIcon(icon, app)
tray.setToolTip("RemoteHub Agent")


def show_window():
    window.showNormal()
    window.show()
    window.raise_()
    window.activateWindow()


def hide_window():
    window.hide()


def tray_activated(reason):
    if reason == QSystemTrayIcon.ActivationReason.DoubleClick:
        show_window()


tray.activated.connect(tray_activated)

menu = QMenu()

action_connect = QAction("Connect", window)
action_connect.triggered.connect(show_window)
menu.addAction(action_connect)

menu.addSeparator()

action_hide = QAction("Hide", window)
action_hide.triggered.connect(hide_window)
menu.addAction(action_hide)

menu.addSeparator()

action_quit = QAction("Quit", window)
action_quit.triggered.connect(app.quit)
menu.addAction(action_quit)

tray.setContextMenu(menu)
tray.show()

# ---------------- Event Loop ----------------

loop = QEventLoop(app)
asyncio.set_event_loop(loop)

with loop:
    loop.create_task(controller.startup())
    loop.run_forever()