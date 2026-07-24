from PySide6.QtWidgets import QWidget,QLabel,QVBoxLayout,QPushButton
from PySide6.QtCore import Qt


class ConnectedPage(QWidget):
    def __init__(self,controller):
        super().__init__()
        self.controller = controller

        layout = QVBoxLayout(self)
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

    def disconnect(self):
        self.controller.disconnect()



