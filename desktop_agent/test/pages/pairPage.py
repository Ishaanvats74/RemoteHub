from PySide6.QtWidgets import QWidget,QLabel,QVBoxLayout,QHBoxLayout,QLineEdit,QPushButton,QMessageBox
from PySide6.QtGui import QIntValidator
from qasync import  asyncSlot
from agent.main import ws_client
from PySide6.QtCore import Qt
import requests
import platform
import asyncio
import socket
import json
from pathlib import Path




class PairPage(QWidget):
    def __init__(self):
        super().__init__()
       

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
    

    def show_error(self, message):
        QMessageBox.warning(self, "Validation Error", message)