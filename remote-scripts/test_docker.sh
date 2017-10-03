# This script is meant for quick & easy install via:
curl -fsSL get.docker.com -o get-docker.sh
sh get-docker.sh

systemctl status docker > /dev/null
dockerServiceStatus=$?
systemctl status docker > ./dockerServiceStatusLogs.txt
docker version > dockerVersion.txt

if [ $dockerServiceStatus -eq 0 ];then
	echo "DOCKER_VERIFIED_SUCCESSFULLY"
else
	echo "DOCKER_VERIFICATION_FAILED"
fi

#TODO : More Tests


#TODO Cleanup
