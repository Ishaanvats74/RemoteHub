from PySide6.QtWidgets import QMainWindow,QApplication, QMenu,QStyle,QSystemTrayIcon,QStackedWidget
from desktop_agent.controller.agent import AgentController
from desktop_agent.pages.connectedPage import ConnectedPage
from PySide6.QtGui import  QIcon,QAction
from desktop_agent.pages.pairPage import PairPage
from qasync import QEventLoop
from pathlib import Path
import asyncio
import sys


class MainWindow(QMainWindow):
    def __init__(self):
        super().__init__()
        self.ws_task = None
        self.controller = None
        self.stack = QStackedWidget()
        self.file_path = Path('token.json')
        self.stylesheet_path = Path('stylesheet.css')
        self.setWindowTitle("RemoteHub Agent")
        self.setFixedSize(420, 260)
        self.pair_page = PairPage(self)
        self.connected_page = ConnectedPage(self)
        self.stack.addWidget(self.pair_page)
        self.stack.addWidget(self.connected_page)
        self.setCentralWidget(self.stack)
        self.setStyleSheet(self.stylesheet_path.read_text())

    def show_pair_page(self):
        print("Switching to pair page")
        self.stack.setCurrentWidget(self.pair_page)

    def show_connected_page(self):
        print("Switching to connected page")
        self.stack.setCurrentWidget(self.connected_page)




app = QApplication(sys.argv)
app.setQuitOnLastWindowClosed(False)

# ---------------- Main Window ----------------
window = MainWindow()
controller = AgentController(window)
window.controller = controller
window.pair_page.controller = controller
window.connected_page.controller = controller
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

# ---------------- Tray Menu ----------------
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