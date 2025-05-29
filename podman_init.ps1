# Variables - change these paths if needed
$otelcolContribPath = "C:\otelcol-contrib"
$configFileName = "config.yaml"
$podName = "elastic-pod"
$elasticsearchImage = "docker.elastic.co/elasticsearch/elasticsearch:9.0.1"
$kibanaImage = "docker.elastic.co/kibana/kibana:9.0.1"
$otelCollectorImage = "docker.io/otel/opentelemetry-collector-contrib:latest"
$memory = "4096"

# Paths
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Definition
$configSourcePath = Join-Path $scriptDir $configFileName
$configDestPath = Join-Path $otelcolContribPath $configFileName

if (-not (Test-Path -Path $otelcolContribPath)) {
    Write-Host "Creating directory $otelcolContribPath"
    New-Item -ItemType Directory -Path $otelcolContribPath -Force
}

Write-Host "Copying config.yaml from script folder to $otelcolContribPath"
Copy-Item -Path $configSourcePath -Destination $configDestPath -Force

Write-Host "Initializing podman machine with volume mount and $memory MB RAM"
podman machine init -v "${otelcolContribPath}:otelcol-contrib" --memory $memory

Write-Host "Starting podman machine"
podman machine start

Write-Host "Creating pod $podName with ports 9200, 5601, 4317, 4318 exposed"
podman pod create --name $podName -p 9200:9200 -p 5601:5601 -p 4317:4317 -p 4318:4318

Write-Host "Running Elasticsearch container in pod"
podman run -d --tls-verify=false --pod $podName --name elasticsearch `
    -e discovery.type=single-node `
    -e xpack.security.enabled=false `
    -e ES_JAVA_OPTS="-Xms512m -Xmx512m" `
    $elasticsearchImage

Write-Host "Running Kibana container in pod"
podman run -d --tls-verify=false --pod $podName --name kibana $kibanaImage

Write-Host "Running OpenTelemetry Collector container in pod"
podman run -d --tls-verify=false --pod $podName --name otel-collector `
	-v /home/core/otelcol-contrib:/etc/otelcol-contrib:Z `
	docker.io/otel/opentelemetry-collector-contrib:latest `
	--config /etc/otelcol-contrib/$configFileName

Write-Host "Setup complete!"
