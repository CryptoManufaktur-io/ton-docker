import os
import asyncio
from pytoniq import LiteClient

server_ip = os.environ["SERVER_IP"]
server_port = int(os.environ["SERVER_PORT"])
server_pubkey = os.environ["SERVER_PUBKEY"]

async def main():
    # Connect directly to your custom liteserver
    client = LiteClient(
        host=server_ip,
        port=server_port,
        server_pub_key=server_pubkey,
        timeout=15,
        trust_level=2
    )

    await client.connect()
    res = await client.get_masterchain_info()
    print(res)
    await client.reconnect()  # can reconnect to an existing object if had any errors
    await client.close()

if __name__ == "__main__":
    import asyncio
    asyncio.run(main())