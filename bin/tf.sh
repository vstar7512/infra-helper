#!/usr/bin/env bash
set -euo pipefail

STACK_DIR=${1:-}
ACTION=${2:-}

if [[ -z "$ACTION" || -z "$STACK_DIR" ]]; then
  echo "Usage: $0 <stack dir path> <init|validate|plan|apply|refresh|output|destroy>"
  exit 1
fi

if [[ -x "$STACK_DIR/tf.sh" ]]; then
  echo "⚙️ Delegating to stack-specific runner: ${STACK_DIR}/tf.sh ..."
  pushd "$STACK_DIR" >/dev/null
  exec "./tf.sh" "$ACTION"
fi

pushd "$STACK_DIR" >/dev/null
echo "▶ Running 'terraform $ACTION' in $STACK_DIR"
case "$ACTION" in
  init)
    : "${tfstate_s3_bucket_name:?must be set}"
    : "${tflock_dynamodb_table_name:?must be set}"
    : "${env_type:?must be set}"
    : "${main_tag:?must be set}"
    : "${aws_region:?must be set}"
    terraform init -reconfigure \
      -backend-config="bucket=${tfstate_s3_bucket_name}" \
      -backend-config="key=${env_type}-${main_tag}/${STACK_DIR%/}/terraform.tfstate" \
      -backend-config="region=${aws_region}" \
      -backend-config="dynamodb_table=${tflock_dynamodb_table_name}" \
      -backend-config="encrypt=true" \
      -input=false
    ;;
  validate)
    terraform validate -input=false
    ;;
  plan)
    terraform plan -input=false
    ;;
  apply)
    terraform apply -input=false -auto-approve -lock=true
    ;;
  refresh)
    terraform refresh -input=false
    ;;
  output)
    terraform output
    ;;
  destroy)
    terraform destroy -input=false -auto-approve -lock=true
    ;;
  *)
    echo "❌ Unknown action: $ACTION"
    popd >/dev/null
    exit 1
    ;;
esac
popd >/dev/null
