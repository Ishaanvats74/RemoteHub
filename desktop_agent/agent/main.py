import websockets
import asyncio
 
# The main function that will handle connection and communication
# with the server
async def ws_client():
    print("WebSocket: Client Connected.")
    url = "ws://127.0.0.1:8000/ws/device"
    # Connect to the server
    async with websockets.connect(url) as ws:
        
        # Stay alive forever, listen to incoming msgs
        while True:
            msg = await ws.recv()
            print(msg)
 
# Start the connection
asyncio.run(ws_client())