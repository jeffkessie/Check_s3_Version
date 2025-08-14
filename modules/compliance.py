import boto3
import os
from datetime import datetime
from openpyxl import Workbook

# AWS client
s3_client = boto3.client('s3')

# Environment variables
S3_BUCKET = os.environ.get("S3_BUCKET") 
S3_KEY = os.environ.get("S3_KEY", f"s3_compliance_report_{datetime.utcnow().strftime('%Y%m%d_%H%M%S')}.xlsx")

def lambda_handler(event=None, context=None):
    #
    s3_data = check_s3_buckets()

    # Create Excel workbook
    wb = Workbook()
    ws_s3 = wb.active
    ws_s3.title = "S3 Buckets"
    ws_s3.append(["BucketName", "Versioning", "LifecycleRules (Expire > 30 days)"])

    for b in s3_data:
        lifecycle = ", ".join(b["LifecycleRules"]) if b["LifecycleRules"] else "None"
        ws_s3.append([b["BucketName"], b["Versioning"], lifecycle])

    
    tmp_file = f"/tmp/{S3_KEY}"
    wb.save(tmp_file)

    
    s3_client.upload_file(tmp_file, S3_BUCKET, S3_KEY)
    print(f"S3 compliance report uploaded to s3://{S3_BUCKET}/{S3_KEY}")

    return {"bucket": S3_BUCKET, "key": S3_KEY}


def check_s3_buckets():
    buckets = s3_client.list_buckets().get("Buckets", [])
    results = []
    for b in buckets:
        name = b["Name"]
        # Versioning
        versioning = s3_client.get_bucket_versioning(Bucket=name).get("Status", "Disabled")
        # Lifecycle rules
        rules_filtered = []
        try:
            lifecycle_cfg = s3_client.get_bucket_lifecycle_configuration(Bucket=name)
            for r in lifecycle_cfg.get("Rules", []):
                expiration = r.get("Expiration", {})
                days = expiration.get("Days", 0)
                if days > 30:
                    rules_filtered.append(r.get("ID", "UnnamedRule"))
        except s3_client.exceptions.ClientError:
            rules_filtered = []

        results.append({
            "BucketName": name,
            "Versioning": versioning,
            "LifecycleRules": rules_filtered
        })
    return results


if __name__ == "__main__":
    lambda_handler()
