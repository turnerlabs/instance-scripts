# instance-scripts

Set of scripts to help manage your instance and make it do things based on AWS EC2 Tags

## Installation
1. mkdir /opt ; cd /opt
1. git clone https://github.com/turnerlabs/instance-scripts.git
2. symlink rc.local to /etc/something

Scripts
=======
*All of these scripts assume you're an EC2 Instance with the AWS CLI pre-installed*

Chef Management Scripts
-----------------------
The chef scripts allow a base AMI to converge itself on boot/creation. These assume that the chef-client is installed on your base AMI

* **get_my_chef_client_pem.sh** - Retrieves a client.rb, client.pem (if exists) or the validator.pem so you can run chef
* **save_my_chef_client_pem.sh** - Uploads a client.pem file after a chef client registered the first time. 
* **run_chef.sh** - calls the above two scripts, and runs chef. Chef logs to STDOUT and /var/log/chef_run.log
*

Instance Scripts
-----------------
* **update_route53.sh** - Looks for the dnsname tag, and will update route53 with the PublicIP (if exists) or internalIP.
* **rc.local** - runs the update_route53 and chef scripts. Also sets the hostname


Management Scripts
--------------------
These scripts are sometimes useful to run on an instance when the instances are more pet than cattle-like

* **format_my_ebs.rb** - Given a device path and a mount point, will paritition, fsck and mount the ebs (or ephermal store)


Tags
=======

* chef_runlist - What is passed to the -r flag of chef-client. ex: "-r role[mychef-role]"
* chef_environment - The chef environment passed via -E to chef-client. If not supplied then the script uses "_default"
* chef_organization - The name of the organization to talk to. Can use managed or internal chef server (that's in your client.rb file)
* dnsname - The FQDN you want in route53. everything after the first period needs to be a route53 HostedZone. Script will find the zoneid. ex: myhostname.awsbest.turner.com 
* hostname - the hostname you want the instance to have. This is what the instance will register to chef with. Can be either "myhostname" or "myhostname-instance_id" if you want to have unique hostnames with similar prefix. The string "instance_id" will be substituted with the node's instance id. 


Required Policies & Buckets
=============================
For Chef, you need a deployment bucket with the following prefix layout:
/chef
/chef/client.pem/$organization/
/chef/client.pem/$organization/$instance_name.pem
/chef/$organization/
/chef/$organization/client.rb
/chef/$organization/$organization-validator.pem

The following Cloudformation Resource snippet outlines the necessary Instance role needed to support these scripts:
	    "InstanceIamInstanceRole": {
	       "Type": "AWS::IAM::Role",
	       "Properties": {
	          "AssumeRolePolicyDocument": {
	             "Version" : "2012-10-17",
	             "Statement": [ {
	                "Effect": "Allow",
	                "Principal": {
	                   "Service": [ "ec2.amazonaws.com" ]
	                },
	                "Action": [ "sts:AssumeRole" ]
	             } ]
	          },
	          "Path": "/",
	          "ManagedPolicyArns": [ "arn:aws:iam::aws:policy/AmazonEC2ReadOnlyAccess" ],
				"Policies": [  
					{
						"PolicyName": "AllowUpdateToRoute53",
						"PolicyDocument": {
							"Version": "2012-10-17",
							"Statement": [
								{
									"Sid": "AllowUpdateToRoute53",
									"Effect": "Allow",
									"Action": [
										"route53:ChangeResourceRecordSets",
										"route53:Get*",
										"route53:List*"
									],
									"Resource": [ "*" ]
								}
							]
						}
					},
					{
						"PolicyName": "AllowAccessToClientPem",
						"PolicyDocument": {
							"Version": "2012-10-17",
							"Statement": [
								{
									"Sid": "AllowAccessToClientPem",
									"Effect": "Allow",
									"Action": [
										"s3:GetObject",
										"s3:PutObject"
									],
									"Resource": [ 
										{"Fn::Join": ["", ["arn:aws:s3:::", {"Ref": "pChefConfigBucket"},  "/chef/client.pem/", 
												{"Ref": "pChefOrganization"}, "/", {"Ref": "pInstanceName" } ]]},
										{"Fn::Join": ["", ["arn:aws:s3:::", {"Ref": "pChefConfigBucket"},  "/chef/", {"Ref": "pChefOrganization"}, "/*" ]]}
									]
								},
								{
									"Sid": "AllowBucketList",
									"Effect": "Allow",
									"Action": [
										"s3:ListBucket"
									],
									"Resource": [ 
										{"Fn::Join": ["", ["arn:aws:s3:::", {"Ref": "pChefConfigBucket"} ]]}
									]
								}
							]
						}
					}
				]
	    	}
	    }

The AllowAccessToClientPem statement is designed to only allow the instance access to the specific organization and client.pem file for the instance name. Least Privledge for the win. 