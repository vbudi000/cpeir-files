#CPEIR files

This repository is my collection of scripts to install IBM Cloud Pak family of products.

How to use this repo in standalone mode:

- Run the install.sh using your entitlement key:

	```
	git clone https://github.com/vbudi000/cpeir-files
	cd cpeir-files
	bash ./install.sh <entitlementKey>
	```

	- This script creates a project called cpeir (to hold installation artifacts)
	- This script creates a serviceaccount called cpeir
	- This script gaves cluster-admin to cpeir (can be removed later - not needed after installation)

- Preparing the runtime image for some of the installation jobs:

	```
	cd runtime
	docker build -t <imagename> .
	docker push <imagename>
	```

- Run the cloud pak installation programs:

	Installation programs are in install sub-directory; you invoke it using the following:

	```
	cd install
	bash ./<cpname>-<cpversion>.sh
	```

	All the files are called <cpname>-<cpversion> or <cpname>-<cpversion>-<cpfeature>; remember to modify the job image name with the image name that you created in the previous command.

- Possibly clean up the cluster admin for cpeir serviceaccount

	```
	oc adm policy remove-cluster-role-from-user cluster-admin -n cpeir -z cpeir
	```
