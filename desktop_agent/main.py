from PySide6.QtWidgets import QMainWindow,QApplication, QMenu,QStyle,QSystemTrayIcon,QStackedWidget
from PySide6.QtGui import  QIcon,QAction
from qasync import QEventLoop
import asyncio
import sys
from PairPage import PairPage
from ConnectedPage import ConnectedPage
from agentcontroller import AgentController
from pathlib import Path

class MainWindow(QMainWindow):

    def __init__(self):
        super().__init__()
        self.ws_task = None

        self.stack = QStackedWidget()
        self.file_path = Path('token.json')
        self.setWindowTitle("RemoteHub Agent")
        self.setFixedSize(420, 260)

        self.pair_page = PairPage()
        self.connected_page = ConnectedPage()

        self.stack.addWidget(self.pair_page)
        self.stack.addWidget(self.connected_page)

        self.setCentralWidget(self.stack)
        
        self.setStyleSheet("""
        QMainWindow {
            background: #F6F8FA;
        }

        QWidget {
            font-size: 13px;
            color: #24292F;
        }

        QLabel#title {
        font-size: 22px;
                font-weight: bold;
                color: #111827;
            }

            QLabel#subtitle {
                color: #6B7280;
            }

            QLabel#status {
                color: #16A34A;
                font-weight: bold;
            }

            QLineEdit {
                padding: 8px;
                border: 1px solid #D0D7DE;
                border-radius: 6px;
                background: white;
            }

            QLineEdit:focus {
                border: 2px solid #2563EB;
            }

            QPushButton {
                background: #2563EB;
                color: white;
                border: none;
                border-radius: 6px;
                padding: 8px;
                font-weight: bold;
                min-height: 34px;
            }

            QPushButton:hover {
                background: #1D4ED8;
            }

            QPushButton#disconnect {
                background: #DC2626;
            }

            QPushButton#disconnect:hover {
                background: #B91C1C;
            }
        """)


app = QApplication(sys.argv)
app.setQuitOnLastWindowClosed(False)

# ---------------- Main Window ----------------
window = MainWindow()
controller = AgentController(window)
# asyncio.create_task(controller.startup())

# ---------------- Tray Icon ----------------
style = app.style()
icon = QIcon(style.standardIcon(QStyle.StandardPixmap.SP_ComputerIcon))

tray = QSystemTrayIcon(icon, app)
tray.setToolTip("RemoteHub Agent")


def show_window():
    window.showNormal()      # Restore if minimized
    window.show()            # Show if hidden
    window.raise_()          # Bring to front
    window.activateWindow()  # Focus the window


def hide_window():
    window.hide()


# Show window when tray icon is double-clicked
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
    window.show()
    loop.run_forever()