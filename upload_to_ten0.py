import subprocess
import os

USE_PROPXY = False
# USE_PROPXY = True

print("USE_PROPXY:", USE_PROPXY)

log = print

PROXY_HOST = "127.0.0.1"

config = dict(
    mark=[
        dict(
            filepath="/Users/matianjun/Dropbox/code/galaxy-bank",
            hostname="ubuntu@43.154.75.104",
            remote_path="/home/ubuntu",
        ),
    ],
)


def sync2production(filepath, hostname, remote_path):
    if USE_PROPXY:
        command = f"""rsync -avH -e "ssh -o ProxyCommand='nc -X 5 -x {PROXY_HOST}:7890 %h %p' " --exclude '{filepath}/test_cache/' --exclude-from={filepath}/.gitignore {filepath} {hostname}:{remote_path}"""
    else:
        command = f"""rsync -avH --exclude '{filepath}/test_cache/' --exclude-from={filepath}/.gitignore {filepath} {hostname}:{remote_path}"""

    log(command)

    r = os.system(command)
    if r == 0:
        log(f"成功地更新代码到:{hostname}")
    else:
        log(f"没有成功地更新代码到:{hostname}")
    return r


def update_batch(config_list: list):
    res = []
    for cfg in config_list:
        r = sync2production(**cfg)
        res.append(r)

    if set(res) != {0}:
        log(f"没有完全同步所有机器")
    else:
        log(f"完全同步所有机器")


if __name__ == "__main__":
    if os.path.exists(config["mark"][0]["filepath"]):
        update_batch(config["mark"])
    else:
        print(f"没有找到folder 路径")
