from PySide6.QtWidgets import QApplication,QMainWindow,QWidget,QLabel,QVBoxLayout,QHBoxLayout,QLineEdit,QPushButton,QStackedWidget,QMessageBox, QMenu,QStyle,QSystemTrayIcon
from PySide6.QtGui import QIntValidator, QIcon,QAction
from qasync import QEventLoop, asyncSlot
from agent.main import ws_client
from PySide6.QtCore import Qt
import requests
import platform
import asyncio
import socket
import json
import sys



class MainWindow(QMainWindow):
    def __init__(self):
        super().__init__()
        self.ws_task = None
        self.file_path = 'token.json'
        self.setWindowTitle("RemoteHub Agent")
        self.setFixedSize(420, 260)
        
        self.stack = QStackedWidget()
        self.stack.addWidget(self.create_pair_page())
        self.stack.addWidget(self.create_connected_page())

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

    def create_pair_page(self):
        page = QWidget()
        layout = QVBoxLayout(page)
        layout.setContentsMargins(24, 24, 24, 24)
        layout.setSpacing(14)

        title = QLabel("RemoteHub Agent")
        title.setObjectName("title")
        title.setAlignment(Qt.AlignCenter)

        subtitle = QLabel("Pair your computer")
        subtitle.setObjectName("subtitle")

        row = QHBoxLayout()
        row.addWidget(QLabel("Pairing Code"))

        self.code_input = QLineEdit()
        self.code_input.setPlaceholderText("Enter 6-digit code")
        self.code_input.setMaxLength(6)
        self.code_input.setValidator(QIntValidator(0, 999999, self))
        self.code_input.returnPressed.connect(self.pair_device)

        row.addWidget(self.code_input)

        self.connect_btn = QPushButton("Connect")
        self.connect_btn.clicked.connect(self.pair_device)

        layout.addWidget(title)
        layout.addWidget(subtitle)
        layout.addLayout(row)
        layout.addWidget(self.connect_btn)
        layout.addStretch()

        return page

    def create_connected_page(self):
        page = QWidget()
        layout = QVBoxLayout(page)
        layout.setContentsMargins(24, 24, 24, 24)
        layout.setSpacing(12)

        title = QLabel("RemoteHub Agent")
        title.setObjectName("title")
        title.setAlignment(Qt.AlignCenter)

        status = QLabel("● Connected")
        status.setObjectName("status")

        layout.addWidget(title)
        layout.addWidget(status)
        layout.addWidget(QLabel("Device: Ishaan-PC"))
        layout.addWidget(QLabel("Status: Online"))
        layout.addWidget(QLabel("Running in background"))

        disconnect_btn = QPushButton("Disconnect")
        disconnect_btn.setObjectName("disconnect")
        disconnect_btn.clicked.connect(self.disconnect)

        layout.addWidget(disconnect_btn)
        layout.addStretch()

        return page

    def show_error(self, message):
        QMessageBox.warning(self, "Validation Error", message)

    @asyncSlot()
    async def pair_device(self):
        code = self.code_input.text().strip()

        if not code:
            self.show_error("Please enter the pairing code.")
            return

        if len(code) != 6:
            self.show_error("Pairing code must contain exactly 6 digits.")
            return

        self.connect_btn.setEnabled(False)

        os_name = platform.system()
        platform_info = platform.platform()
        hostname = socket.gethostname()

        data = {
            "code": code,
            "hostname": hostname,
            "os": os_name,
            "platform": platform_info,
        }

        try:
            response = await asyncio.to_thread(requests.post,"http://127.0.0.1:8000/devices/pair",json=data,timeout=10,)

            response.raise_for_status()

            result = response.json()

            if "device_token" not in result:
                self.show_error("Server returned an invalid response.")
                return

            self.validate_token(result)

            self.stack.setCurrentIndex(1)

            if self.ws_task is None:
                self.ws_task = asyncio.create_task(ws_client(result["device_token"]))

        except requests.exceptions.Timeout:
            self.show_error("Connection timed out.")

        except requests.exceptions.ConnectionError:
            self.show_error("Unable to connect to the server.")

        except requests.exceptions.HTTPError:
            try:
                error = response.json().get("detail", response.text)
            except Exception:
                error = response.text

            self.show_error(error)

        except requests.exceptions.RequestException as e:
            self.show_error(str(e))

        except json.JSONDecodeError:
            self.show_error("Server returned an invalid response.")

        except Exception as e:
            self.show_error(f"Unexpected error:\n{e}")

        finally:
            self.connect_btn.setEnabled(True)

    @asyncSlot()
    async def disconnect(self):
        if self.ws_task:
            self.ws_task.cancel()

            try:
                await self.ws_task
            except asyncio.CancelledError:
                pass

            self.ws_task = None

        self.stack.setCurrentIndex(0)

    def validate_token(self, result):
        try:
            with open(self.file_path, "w", encoding="utf-8") as f:
                json.dump(result, f, indent=4)

        except OSError as e:
            QMessageBox.critical(self,"Error",f"Unable to save token.\n{e}")


app = QApplication(sys.argv)
app.setQuitOnLastWindowClosed(False)

# ---------------- Main Window ----------------
window = MainWindow()
window.show()

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
    loop.run_forever()