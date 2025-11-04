#!/usr/bin/env python3
import json, os, sys
from typing import Any, Dict, List
import boto3
from botocore.exceptions import ClientError
from datetime import datetime, date
from decimal import Decimal

# -------------------------
# Help
# -------------------------
def show_help() -> None:
  print("""
Usage: set required environment variables before running:

  task_definition_name   ECS task definition name (family[:revision])
  ecs_cluster_name       ECS cluster name
  aws_region             AWS region
  subnets                Comma-separated list of subnet IDs
  security_groups        Comma-separated list of security group IDs
  assign_public_ip       Assign public IP to the task ("ENABLED" or "DISABLED")

Optional:
  overrides (JSON array) for environment overrides per container

Example:
  export task_definition_name="my-task"
  export ecs_cluster_name="my-cluster"
  export aws_region="eu-west-2"
  export subnets="subnet-aaa,subnet-bbb"
  export security_groups="sg-111,sg-222"
  export assign_public_ip="ENABLED"
  export overrides="$(cat <<'JSON'
[
  {
    "target_container_name": "web",
    "environment": [
      {"name": "DEBUG", "value": "true"},
      {"name": "MODE", "value": "dev"}
    ]
  }
]
JSON
)"
  ./ecs/run_oneoff_task.py
""")


# -------------------------
# Utilities
# -------------------------
def env(name: str, default: str | None = None) -> str | None:
  v = os.environ.get(name)
  return v.strip() if v is not None else default

def split_csv(v: str | None) -> List[str]:
  return [x for x in (v or "").replace(" ", "").split(",") if x]

def pretty(obj: Any) -> str:
  return json.dumps(obj, indent=2, ensure_ascii=False)

def die(msg: str):
  sys.stderr.write(msg + "\n")
  sys.exit(1)

def _json_default(o):
    if isinstance(o, (datetime, date)):
        return o.isoformat()
    if isinstance(o, Decimal):
        return float(o)
    if isinstance(o, (bytes, bytearray)):
        return o.decode("utf-8", "replace")
    # fallback
    return str(o)

def pretty(obj) -> str:
    return json.dumps(obj, indent=2, ensure_ascii=False, default=_json_default)


# -------------------------
# Config loaders
# -------------------------
def load_required() -> Dict[str, str]:
  required = ["task_definition_name","ecs_cluster_name","aws_region"]
  missing = [k for k in required if not env(k)]
  if missing: die(f"❌ Missing required env vars: {', '.join(missing)}")
  return {k: env(k) for k in required}

def load_network() -> Dict[str, Any]:
  subnets_raw = env("subnets", env("subnet_id",""))
  sgs_raw = env("security_groups", env("sg_id",""))
  assign = (env("assign_public_ip","DISABLED") or "DISABLED").upper()
  if assign not in ("ENABLED","DISABLED"):
    die("❌ assign_public_ip must be ENABLED or DISABLED")
  subnets = split_csv(subnets_raw)
  sgs = split_csv(sgs_raw)
  if not subnets: die("❌ No subnets provided. Set 'subnets' or legacy 'subnet_id'.")
  if not sgs: die("❌ No security groups provided. Set 'security_groups' or legacy 'sg_id'.")
  return {"subnets": subnets, "sgs": sgs, "assign": assign}

def load_overrides() -> List[Dict[str,Any]]:
  s = env("overrides","")
  if not s: return []
  try:
    data = json.loads(s)
    if not isinstance(data, list): die("❌ overrides must be a JSON array")
    return data
  except Exception as e:
    die(f"❌ overrides is not valid JSON: {e}")


# -------------------------
# AWS interactions
# -------------------------
def get_clients(region: str) -> Dict[str, Any]:
  return {
    "ecs": boto3.client("ecs", region_name=region),
    "ec2": boto3.client("ec2", region_name=region),
    "sts": boto3.client("sts", region_name=region)
  }

def fetch_account_id(sts) -> str:
  try:
    return sts.get_caller_identity()["Account"]
  except ClientError as e:
    die(f"❌ Failed to get AWS account ID: {e}")

def fetch_task_definition(ecs, task_def: str) -> Dict[str,Any]:
  try:
    return ecs.describe_task_definition(taskDefinition=task_def)["taskDefinition"]
  except ClientError as e:
    die(f"❌ Task definition not found '{task_def}': {e}")

def validate_subnets(ec2, subnets: List[str], region: str) -> None:
  try:
    ec2.describe_subnets(SubnetIds=subnets)
    for sn in subnets: print(f"✅ Subnet exists: {sn}")
  except ClientError as e:
    die(f"❌ Subnet check failed: {e}")

def validate_sgs(ec2, sgs: List[str], region: str) -> None:
  try:
    ec2.describe_security_groups(GroupIds=sgs)
    for sg in sgs: print(f"✅ Security Group exists: {sg}")
  except ClientError as e:
    die(f"❌ Security group check failed: {e}")


# -------------------------
# Overrides handling
# -------------------------
def validate_overrides_targets(task_def: Dict[str,Any], overrides: List[Dict[str,Any]]) -> None:
  existing = {c["name"] for c in task_def.get("containerDefinitions", [])}
  for i, item in enumerate(overrides, start=1):
    tgt = (item or {}).get("target_container_name")
    if not tgt: die(f"❌ overrides[{i}] missing 'target_container_name'")
    if tgt not in existing:
      die(f"❌ target_container_name '{tgt}' not found in task definition containers: {', '.join(sorted(existing))}")

def build_ecs_overrides(overrides: List[Dict[str,Any]]) -> Dict[str,Any] | None:
  if not overrides: return None
  conv = []
  for i, item in enumerate(overrides, start=1):
    tgt = item["target_container_name"]
    entry: Dict[str,Any] = {"name": tgt}
    env_list = item.get("environment")
    if env_list:
      if not isinstance(env_list, list): die(f"❌ overrides[{i}].environment must be an array")
      entry["environment"] = env_list
      conv.append(entry)
  res = {"containerOverrides": conv}
  print("✅ Overrides JSON built")
  print(pretty(res))
  return res


# -------------------------
# Run task
# -------------------------
def build_network_configuration(subnets: List[str], sgs: List[str], assign: str) -> Dict[str,Any]:
  nc = {"awsvpcConfiguration": {"subnets": subnets, "securityGroups": sgs, "assignPublicIp": assign}}
  print("✅ Network config:")
  print(pretty(nc))
  return nc

def run_task(ecs, *, cluster: str, task_def: str, network: Dict[str,Any], overrides: Dict[str,Any] | None) -> Dict[str,Any]:
  params = {
    "cluster": cluster,
    "launchType": "FARGATE",
    "taskDefinition": task_def,
    "enableExecuteCommand": True,
    "networkConfiguration": network,
  }
  if overrides: params["overrides"] = overrides
  try:
    return ecs.run_task(**params)
  except ClientError as e:
    die(f"❌ ecs.run_task failed: {e}")

def summarize(resp: Dict[str, Any]) -> None:
    tasks = resp.get("tasks", [])
    fails = resp.get("failures", [])

    if tasks:
        print(pretty({
            "tasks": [
                {
                    "taskArn": t.get("taskArn"),
                    "lastStatus": t.get("lastStatus"),
                    "desiredStatus": t.get("desiredStatus"),
                    "launchType": t.get("launchType"),
                    "platformVersion": t.get("platformVersion"),
                    "createdAt": t.get("createdAt"),
                    "startedAt": t.get("startedAt"),
                    "containers": [
                        {"name": c.get("name"), "lastStatus": c.get("lastStatus")}
                        for c in t.get("containers", [])
                    ],
                } for t in tasks
            ]
        }))
        print("\nSummary:")
        for t in tasks:
            print(f"  - {t.get('taskArn')}  status={t.get('lastStatus')}")
    elif fails:
        sys.stderr.write(pretty({"failures": fails}) + "\n")
        sys.exit(1)
    else:
        print(pretty(resp))


# -------------------------
# Main
# -------------------------
def main() -> None:
  if len(sys.argv) > 1 and sys.argv[1] in ("-h", "--help"):
    show_help()
    sys.exit(0)

  req = load_required()
  net = load_network()
  ov = load_overrides()

  clients = get_clients(req["aws_region"])
  print("================================= fetch_resources =================================")
  acct = fetch_account_id(clients["sts"])
  print(f"✅ Account ID: {acct}")

  print("================================= check_resources =================================")
  td = fetch_task_definition(clients["ecs"], req["task_definition_name"])
  print(f"✅ Task definition exists: {req['task_definition_name']}")
  validate_subnets(clients["ec2"], net["subnets"], req["aws_region"])
  validate_sgs(clients["ec2"], net["sgs"], req["aws_region"])

  if ov:
    validate_overrides_targets(td, ov)
  ecs_overrides = build_ecs_overrides(ov)
  network = build_network_configuration(net["subnets"], net["sgs"], net["assign"])

  print("================================= run_task =================================")
  resp = run_task(
    clients["ecs"],
    cluster=req["ecs_cluster_name"],
    task_def=req["task_definition_name"],
    network=network,
    overrides=ecs_overrides,
  )
  summarize(resp)

if __name__ == "__main__":
  main()
