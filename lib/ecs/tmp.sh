tf_state_s3_url="s3://$tfstate_s3_bucket_name/${env_type}-${main_tag}/base/terraform.tfstate"
# Subnet ID
subnet_id="$(./tf_output/get_tf_output_key.sh "$tf_state_s3_url" 'vpc.value.private_subnet_id')" || {
echo "❌ Unable to resolve subnet_id from tfstate" >&2
exit 1
}
echo "Subnet ID: $subnet_id"
# Security Group ID
sg_id="$(./tf_output/get_tf_output_key.sh "$tf_state_s3_url" 'security_groups.value["test-example-a-cloudmap-checker-ecs-oneoff-task-sg"].security_group_id')" || {
echo "❌ Unable to resolve sg_id from tfstate" >&2
exit 1
}
echo "Security Group ID: $sg_id"
