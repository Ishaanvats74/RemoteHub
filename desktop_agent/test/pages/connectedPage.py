from PySide6.QtWidgets import QWidget,QLabel,QVBoxLayout,QHBoxLayout,QPushButton,QMessageBox
from agent.main import ws_client
from qasync import  asyncSlot
from PySide6.QtCore import Qt
from pathlib import Path
import asyncio



class ConnectedPage(QWidget):
    def __init__(self):
        super().__init__()

   

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
    async def disconnect(self):
        if self.ws_task:
            self.ws_task.cancel()

            try:
                await self.ws_task
            except asyncio.CancelledError:
                pass

            self.ws_task = None




