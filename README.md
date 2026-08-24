# Peering / Transit / RPKI / MANRS Lab —— Ansible 自动化

配套 Obsidian 笔记 `2.1 Peering实验-Transit-RPKI-MANRS.md` 与 `2.2 Peering实验自动化.md`。
在 EVE-NG 里搭好 13 节点拓扑后，用本工程一键完成寻址 → 装组件 → 下发配置 → 验证。

## 目录结构
```
Peering_internet_lab/
├── ansible.cfg              # 关 host key 检查、指定 inventory
├── site.yml                 # 一键编排：01→02→03→04
├── inventory/hosts.ini      # 按角色分组，IP=DHCP 固定分配
├── group_vars/all.yml       # ★唯一事实源：AS/前缀/loopback/MAC-IP/IX/PNI/community
├── host_vars/               # 各外部对端(ASN/邻居/宣告前缀)
│   ├── transit1.yml transit2.yml
│   ├── eyeballA.yml eyeballB.yml eyeballC.yml
│   └── cdn.yml
├── templates/               # Jinja2 模板
│   ├── dhcpd.conf.j2        # DHCP MAC→固定IP
│   ├── frr_rr.conf.j2       # RR：IS-IS + iBGP-RR
│   ├── frr_peer.conf.j2     # Transit/Eyeball/CDN 通用
│   ├── bird_rs.conf.j2      # IX Route-Server
│   ├── slurm.json.j2        # Routinator 本地 ROA
│   ├── xr_policy.conf.j2    # BR 三类边界 route-policy + MANRS
│   ├── xr_br1.conf.j2       # BR1 主体(接 Transit-1/PNI主)
│   └── xr_br2.conf.j2       # BR2 主体(接 Transit-2/PNI备)
└── playbooks/
    ├── 01-dhcp.yml          # 控制节点起 DHCP
    ├── 02-install.yml       # 各角色装组件(signed-by 源)
    ├── 03-config.yml        # 渲染+幂等下发(frr-reload/birdc/iosxr_config)
    └── 04-verify.yml        # 断言 IS-IS/iBGP/RPKI/选路
```

## 使用前必填（搜 `REPLACE_` 全部替换成真值）
这些是笔记里未定到主机位、需按你 EVE-NG 实际接线确定的地址：

| 位置 | 变量 | 含义 |
|---|---|---|
| inventory/hosts.ini | `REPLACE_BR1/BR2_MGMT_IP` | 两台 BR 管理口 IP(见 2.1 M1/M2) |
| group_vars/all.yml | `REPLACE_IX_RS/BR1/BR2_IP` | IX 平面地址(RS=.1 BR1=.10 BR2=.11) |
| group_vars/all.yml | `REPLACE_TRANSIT1/2_PEER` | 上游 /30 对端(2.1 L5/L6) |
| group_vars/all.yml | `REPLACE_PNI_A/C_PEER` | PNI /30 对端(2.1 L12/L13) |
| host_vars/*.yml | `REPLACE_*_LINK_IP`, `REPLACE_BRx_*_IP` | 各对端本地接口 IP 及其对侧 BR 地址 |
| templates/bird_rs.conf.j2 | `REPLACE_IX_EYEBALLB/CDN_IP` | IX 平面上 Eyeball-B/CDN 地址 |

> `group_vars/all.yml` 里的 loopback、管理网、DHCP MAC/IP 已按 2.1 §3.1 + 2.2 §一/§三.1 填好，无需改动。

一键找出所有待填项：
```bash
cd ~/PycharmProjects/Peering_internet_lab
grep -rn REPLACE_ .
```

## 运行
```bash
# 语法自检
ansible-playbook site.yml --syntax-check

# 分步执行(推荐首次)
ansible-playbook playbooks/01-dhcp.yml      # 控制节点起 DHCP，各节点重启网卡拿固定 IP
ansible-playbook playbooks/02-install.yml   # 装 FRR/BIRD/Routinator/nfdump
ansible-playbook playbooks/03-config.yml    # 下发配置(XR 建议先 --limit xr --check --diff)
ansible-playbook playbooks/04-verify.yml    # 断言通断

# 或一键重建(EVE-NG 重开 lab 后)
ansible-playbook site.yml
```

## 设计要点
- **单一事实源**：改编址/策略只动 `group_vars/all.yml`，模板全部引用变量。
- **幂等热加载**：FRR `frr-reload.py`、BIRD `birdc configure`、XR `iosxr_config` 增量合并，不整机重启。
- **混合纳管**：Linux 走 SSH，XRv9k 走 `network_cli` + `cisco.iosxr`。
- **可重复**：`site.yml` 串起四步，lab 随时销毁重建 = Infra-as-Code。
