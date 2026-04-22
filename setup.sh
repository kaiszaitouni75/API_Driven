#!/bin/bash

# ============================================================
# ATELIER API-DRIVEN INFRASTRUCTURE - Script de setup complet
# ============================================================

AWS_ENDPOINT="http://localhost:4566"
AWS_REGION="us-east-1"
LAMBDA_NAME="ec2-controller"
API_NAME="ec2-api"

die() { echo "❌ ERREUR : $1"; exit 1; }
RUN_AWS="aws --endpoint-url=$AWS_ENDPOINT --region $AWS_REGION"

echo ""
echo "╔══════════════════════════════════════════╗"
echo "║     SETUP API-DRIVEN INFRASTRUCTURE      ║"
echo "╚══════════════════════════════════════════╝"
echo ""

# ─────────────────────────────────────────────────────
# Étape 0 : Vérification LocalStack + détection IP Docker
# ─────────────────────────────────────────────────────
echo "⏳ [0/6] Vérification de LocalStack..."
curl -s "$AWS_ENDPOINT/_localstack/health" | grep -q "running\|available" \
  || die "LocalStack ne tourne pas. Lance : localstack start -d"
echo "✅ LocalStack est opérationnel"

echo "🔍 Détection de l'IP interne de LocalStack..."
DOCKER_IP=$(docker inspect localstack-main 2>/dev/null | python3 -c "
import sys, json
data = json.load(sys.stdin)
networks = data[0]['NetworkSettings']['Networks']
for name, net in networks.items():
    ip = net.get('IPAddress', '')
    if ip and name == 'bridge':
        print(ip); exit()
for name, net in networks.items():
    ip = net.get('IPAddress', '')
    if ip:
        print(ip); exit()
" 2>/dev/null)

if [ -z "$DOCKER_IP" ]; then
    DOCKER_IP="172.17.0.2"
    echo "⚠️  IP non détectée, utilisation de $DOCKER_IP par défaut"
else
    echo "✅ IP Docker LocalStack : $DOCKER_IP"
fi

LAMBDA_INTERNAL_ENDPOINT="http://${DOCKER_IP}:4566"
echo "✅ Endpoint Lambda interne : $LAMBDA_INTERNAL_ENDPOINT"
echo ""

# ─────────────────────────────────────────────────────
# Étape 1 : Volume EBS
# ─────────────────────────────────────────────────────
echo "⏳ [1/6] Création du Volume EBS..."
VOLUME_ID=$($RUN_AWS ec2 create-volume \
  --availability-zone us-east-1a \
  --size 8 \
  --output json | python3 -c "import sys,json; print(json.load(sys.stdin)['VolumeId'])")
[ -z "$VOLUME_ID" ] && die "Impossible de créer le volume EBS"
echo "✅ Volume créé : $VOLUME_ID"
echo ""

# ─────────────────────────────────────────────────────
# Étape 2 : Snapshot
# ─────────────────────────────────────────────────────
echo "⏳ [2/6] Création du Snapshot..."
SNAP_ID=$($RUN_AWS ec2 create-snapshot \
  --volume-id "$VOLUME_ID" \
  --output json | python3 -c "import sys,json; print(json.load(sys.stdin)['SnapshotId'])")
[ -z "$SNAP_ID" ] && die "Impossible de créer le snapshot"
echo "✅ Snapshot créé : $SNAP_ID"
echo ""

# ─────────────────────────────────────────────────────
# Étape 3 : AMI
# ─────────────────────────────────────────────────────
echo "⏳ [3/6] Enregistrement de l'AMI..."
AMI_ID=$($RUN_AWS ec2 register-image \
  --name "dummy-ami" \
  --description "dummy ami for localstack" \
  --architecture x86_64 \
  --root-device-name /dev/xvda \
  --virtualization-type hvm \
  --block-device-mappings "[{\"DeviceName\":\"/dev/xvda\",\"Ebs\":{\"SnapshotId\":\"$SNAP_ID\",\"VolumeSize\":8,\"DeleteOnTermination\":true}}]" \
  --output json | python3 -c "import sys,json; print(json.load(sys.stdin)['ImageId'])")
[ -z "$AMI_ID" ] && die "Impossible de créer l'AMI"
echo "✅ AMI créée : $AMI_ID"
echo ""

# ─────────────────────────────────────────────────────
# Étape 4 : Instance EC2
# ─────────────────────────────────────────────────────
echo "⏳ [4/6] Création de l'instance EC2..."
INSTANCE_ID=$($RUN_AWS ec2 run-instances \
  --image-id "$AMI_ID" \
  --instance-type t2.micro \
  --count 1 \
  --output json | python3 -c "import sys,json; print(json.load(sys.stdin)['Instances'][0]['InstanceId'])")
[ -z "$INSTANCE_ID" ] && die "Impossible de créer l'instance EC2"
echo "✅ Instance EC2 créée : $INSTANCE_ID"
echo ""

# ─────────────────────────────────────────────────────
# Étape 5 : Fonction Lambda
# ─────────────────────────────────────────────────────
echo "⏳ [5/6] Création de la fonction Lambda..."
$RUN_AWS lambda delete-function --function-name "$LAMBDA_NAME" 2>/dev/null || true

ENDPOINT_FOR_LAMBDA="$LAMBDA_INTERNAL_ENDPOINT"

cat > /tmp/lambda_function.py << PYEOF
import boto3
import json
import os

def lambda_handler(event, context):
    endpoint = os.environ.get('AWS_ENDPOINT', 'http://localhost:4566')
    ec2 = boto3.client(
        'ec2',
        endpoint_url=endpoint,
        region_name='us-east-1',
        aws_access_key_id='test',
        aws_secret_access_key='test'
    )
    if isinstance(event.get('body'), str):
        body = json.loads(event['body'])
    else:
        body = event

    action = body.get('action')
    instance_id = body.get('instance_id')

    if not action or not instance_id:
        return {"statusCode": 400, "body": json.dumps({"error": "action et instance_id requis"})}

    try:
        if action == 'start':
            ec2.start_instances(InstanceIds=[instance_id])
            return {"statusCode": 200, "body": json.dumps({"message": f"Instance {instance_id} demarree"})}
        elif action == 'stop':
            ec2.stop_instances(InstanceIds=[instance_id])
            return {"statusCode": 200, "body": json.dumps({"message": f"Instance {instance_id} arretee"})}
        elif action == 'status':
            r = ec2.describe_instances(InstanceIds=[instance_id])
            state = r['Reservations'][0]['Instances'][0]['State']['Name']
            return {"statusCode": 200, "body": json.dumps({"instance_id": instance_id, "state": state})}
        else:
            return {"statusCode": 400, "body": json.dumps({"error": "action invalide : start / stop / status"})}
    except Exception as e:
        return {"statusCode": 500, "body": json.dumps({"error": str(e)})}
PYEOF

cd /tmp && zip -q function.zip lambda_function.py && cd - > /dev/null

$RUN_AWS lambda create-function \
  --function-name "$LAMBDA_NAME" \
  --runtime python3.12 \
  --handler lambda_function.lambda_handler \
  --zip-file fileb:///tmp/function.zip \
  --role arn:aws:iam::000000000000:role/lambda-role \
  --timeout 30 \
  --environment "Variables={AWS_ENDPOINT=$ENDPOINT_FOR_LAMBDA}" \
  --output json > /dev/null \
  || die "Échec création Lambda"

echo "✅ Fonction Lambda déployée (endpoint : $ENDPOINT_FOR_LAMBDA)"
echo ""

# ─────────────────────────────────────────────────────
# Étape 6 : API Gateway
# ─────────────────────────────────────────────────────
echo "⏳ [6/6] Création de l'API Gateway..."

EXISTING_API=$($RUN_AWS apigateway get-rest-apis --output json | python3 -c "
import sys, json
for a in json.load(sys.stdin).get('items', []):
    if a['name'] == 'ec2-api':
        print(a['id']); break
" 2>/dev/null || true)

if [ -n "$EXISTING_API" ]; then
    $RUN_AWS apigateway delete-rest-api --rest-api-id "$EXISTING_API" 2>/dev/null || true
    sleep 2
fi

API_ID=$($RUN_AWS apigateway create-rest-api \
  --name "$API_NAME" \
  --output json | python3 -c "import sys,json; print(json.load(sys.stdin)['id'])")
[ -z "$API_ID" ] && die "Impossible de créer l'API Gateway"

ROOT_ID=$($RUN_AWS apigateway get-resources \
  --rest-api-id "$API_ID" \
  --output json | python3 -c "
import sys,json
items=json.load(sys.stdin)['items']
print([i['id'] for i in items if i['path']=='/'][0])")

RESOURCE_ID=$($RUN_AWS apigateway create-resource \
  --rest-api-id "$API_ID" \
  --parent-id "$ROOT_ID" \
  --path-part ec2 \
  --output json | python3 -c "import sys,json; print(json.load(sys.stdin)['id'])")

$RUN_AWS apigateway put-method \
  --rest-api-id "$API_ID" \
  --resource-id "$RESOURCE_ID" \
  --http-method POST \
  --authorization-type NONE \
  --output json > /dev/null

LAMBDA_ARN="arn:aws:lambda:${AWS_REGION}:000000000000:function:${LAMBDA_NAME}"
URI="arn:aws:apigateway:${AWS_REGION}:lambda:path/2015-03-31/functions/${LAMBDA_ARN}/invocations"

$RUN_AWS apigateway put-integration \
  --rest-api-id "$API_ID" \
  --resource-id "$RESOURCE_ID" \
  --http-method POST \
  --type AWS_PROXY \
  --integration-http-method POST \
  --uri "$URI" \
  --output json > /dev/null

$RUN_AWS apigateway create-deployment \
  --rest-api-id "$API_ID" \
  --stage-name prod \
  --output json > /dev/null

echo "✅ API Gateway créée (ID: $API_ID)"
echo ""

# ─────────────────────────────────────────────────────
# Sauvegarde .env
# ─────────────────────────────────────────────────────
cat > .env << ENVEOF
INSTANCE_ID=${INSTANCE_ID}
API_ID=${API_ID}
AMI_ID=${AMI_ID}
AWS_ENDPOINT=${AWS_ENDPOINT}
AWS_REGION=${AWS_REGION}
LAMBDA_NAME=${LAMBDA_NAME}
DOCKER_IP=${DOCKER_IP}
ENVEOF
echo "✅ Configuration sauvegardée dans .env"
echo ""

# ─────────────────────────────────────────────────────
# Makefile
# ─────────────────────────────────────────────────────
cat > Makefile << MAKEEOF
include .env

start:
	@echo "Demarrage de l'instance \$(INSTANCE_ID)..."
	@curl -s -X POST "\$(AWS_ENDPOINT)/restapis/\$(API_ID)/prod/_user_request_/ec2" \
	  -H "Content-Type: application/json" \
	  -d '{"action": "start", "instance_id": "\$(INSTANCE_ID)"}' | python3 -m json.tool

stop:
	@echo "Arret de l'instance \$(INSTANCE_ID)..."
	@curl -s -X POST "\$(AWS_ENDPOINT)/restapis/\$(API_ID)/prod/_user_request_/ec2" \
	  -H "Content-Type: application/json" \
	  -d '{"action": "stop", "instance_id": "\$(INSTANCE_ID)"}' | python3 -m json.tool

status:
	@echo "Statut de l'instance \$(INSTANCE_ID)..."
	@curl -s -X POST "\$(AWS_ENDPOINT)/restapis/\$(API_ID)/prod/_user_request_/ec2" \
	  -H "Content-Type: application/json" \
	  -d '{"action": "status", "instance_id": "\$(INSTANCE_ID)"}' | python3 -m json.tool

describe:
	@aws --endpoint-url=\$(AWS_ENDPOINT) ec2 describe-instances --region \$(AWS_REGION)

setup:
	@bash setup.sh

help:
	@echo "make start  -> Demarrer l'instance EC2"
	@echo "make stop   -> Arreter l'instance EC2"
	@echo "make status -> Voir l'etat de l'instance"
MAKEEOF
echo "✅ Makefile généré"
echo ""

# ─────────────────────────────────────────────────────
# Test automatique
# ─────────────────────────────────────────────────────
echo "🧪 Test automatique de l'API (status)..."
sleep 2
TEST_RESULT=$(curl -s -X POST \
  "$AWS_ENDPOINT/restapis/$API_ID/prod/_user_request_/ec2" \
  -H "Content-Type: application/json" \
  -d "{\"action\": \"status\", \"instance_id\": \"$INSTANCE_ID\"}")
echo "Résultat : $TEST_RESULT"
echo ""

# ─────────────────────────────────────────────────────
# Résumé final
# ─────────────────────────────────────────────────────
echo "╔══════════════════════════════════════════════════════════════╗"
echo "║                     ✅ SETUP TERMINÉ                        ║"
echo "╠══════════════════════════════════════════════════════════════╣"
printf "║  Volume EBS    : %-44s║\n" "$VOLUME_ID"
printf "║  Snapshot      : %-44s║\n" "$SNAP_ID"
printf "║  AMI           : %-44s║\n" "$AMI_ID"
printf "║  Instance EC2  : %-44s║\n" "$INSTANCE_ID"
printf "║  API ID        : %-44s║\n" "$API_ID"
printf "║  IP Docker     : %-44s║\n" "$DOCKER_IP"
echo "╠══════════════════════════════════════════════════════════════╣"
echo "║  make start / make stop / make status                        ║"
echo "╚══════════════════════════════════════════════════════════════╝"
echo ""
echo "🔗 URL API : $AWS_ENDPOINT/restapis/$API_ID/prod/_user_request_/ec2"
echo ""
