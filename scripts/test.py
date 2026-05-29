import os
import asyncio
from pytoniq import LiteClient

server_ip = int(os.environ["SERVER_IP"])
server_port = int(os.environ["SERVER_PORT"])
server_pubkey = os.environ["SERVER_PUBKEY"]

# Your custom liteserver config (update with your values)
server_ip = 12345678  # Replace with your IP decimal representation. 2130706433 = localhost.
server_port = 30003    # Replace with your port
server_pubkey = "bbD8cX9einzbQAktAfpnudxBr71nYU6xkY63SCfi82o="  # Replace with your key

# Convert IP integer to string format
def int_to_ip(ip_int):
    return f"{(ip_int >> 24) & 255}.{(ip_int >> 16) & 255}.{(ip_int >> 8) & 255}.{ip_int & 255}"

async def main():
    # Connect directly to your custom liteserver
    client = LiteClient(
        host=int_to_ip(server_ip),
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