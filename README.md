# pgbouncer-container
This Dockerfile + helm chart will create a pgBouncer docker image and pgBouncer installation on Google Kubernetes Engine on Google Cloud.

This helm chart should work on other Kubernetes Engines, but has not been tested

## Features
Builds 1 .. N pods containing a pgBouncer instance.  By default the installation builds an internal load balancer IP address as well as exposes statistics about each pgBouncer via a Prometheus Exporter sidecar

 - Currently tested against GKE version >= 1.29.1-gke.1589017
 - `google-cloud-sdk-gke-gcloud-auth-plugin` must be installed
   - sudo yum install google-cloud-sdk-gke-gcloud-auth-plugin

## Installation

### Clone the repo
 - Clone the repo into a ubuntu (or equivalent) machine that has docker

### Docker Build

To build a docker image:
- docker build -t pgbouncer:1.22.1 -t pgbouncer:latest --build-arg REPO_TAG=1.22.1 --no-cache .

Tag the image for upload to a common image repository (if necessary):
 - docker tag [IMAGE ID] [repo url]:[tag]
 - docker tag [IMAGE ID] [repo url]:latest

Push the images to the central repository (if necessary):
 - docker push [repo url] --all-tags

List the artifacts.  For example, in GCP:
 - gcloud artifacts docker images list [repo url] --include-tags

### Prepare the Postgres Database

Create a user to be used by pgBouncer for authentication.  This user will only have permissions to read the pg_shadow table via a function.

 - Create user in the console
 - In the database alter the newly created user
   - alter user pgbouncer_auth_user with NOCREATEROLE;
   - alter user pgbouncer_auth_user with NOCREATEDB;
   - revoke alloydbsuperuser from pgbouncer_auth_user; (if using AlloyDB)
   - grant create on schema public to pgbouncer_auth_user;
 - In the console set the flag `alloydb.pg_shadow_select_role` to the newly created `pgbouncer_auth_user`
 - Create the following function:
    ```
    CREATE OR REPLACE FUNCTION public.lookup(INOUT p_user name, OUT p_password text)
    RETURNS record
    LANGUAGE sql
    SECURITY DEFINER
    SET search_path TO 'pg_catalog'
    AS $function$SELECT usename, passwd FROM pg_shadow WHERE usename = p_user$function$;
    ```
 - Revoke permission from the auth user:
   - revoke create on schema public from pgbouncer_auth_user;

### Prepare the Kubernetes Cluster
 - Create a gcloud service account with the following IAM roles
    - Artifact Registry Repository Administrator
    - Cloud AlloyDB Database User
    - Kubernetes Engine Admin
    - Kubernetes Engine Cluster Admin
    - Service Account Token Creator
    - Service Usage Consumer
    - AlloyDB Admin
    - CloudSQL Admin
 - Set up the gcloud auth / impersonation
    - gcloud config set auth/impersonate_service_account [service account created in previous step]
    - gcloud container clusters get-credentials [gke cluster name] --region [region name]
- Create a kubernetes namespace
    - kubectl create namespace pgb-namespace
- Create a kubernetes service account in the newly created namespace
    - kubectl create serviceaccount cloudsql-k8s-sa --namespace=pgb-namespace
- Add a binding from the kubernetes service account to the gcloud service account:
   ```
    gcloud iam service-accounts add-iam-policy-binding \
    [gcloud service account] \
    --role roles/iam.workloadIdentityUser \
    --member "serviceAccount:db-black-belts-playground-01.svc.id.goog[pgb-namespace/cloudsql-k8s-sa]"
    ```
- Annotate the kubernetes service account
    ```
    kubectl annotate serviceaccount \
    --namespace=pgb-namespace \
    cloudsql-k8s-sa \
    iam.gke.io/[gcloud service account] --overwrite=true
    ```
- Install the helm chart (dry run first)
    ```
    helm install gke-bouncer --values values.yaml --dry-run --debug \
    --version 1.22.1 --namespace=pgb-namespace \
    [$HOME/pgbouncer-container/helm]
    ```
- Install the helm chart
    ```
    helm install gke-bouncer --values values.yaml \
    --version 1.22.1 --namespace=pgb-namespace \
    [$HOME/pgbouncer-container/helm]
    ```
- To upgrade the chart with a later version
    ```
    helm upgrade gke-bouncer --values values.yaml \
    --version 1.22.1 --namespace=pgb-namespace \
    [$HOME/pgbouncer-container/helm]
    ```

### pgBouncer configuration
Within the `values.yaml` file there is a section labeled `config:`.  This section contains the basic pgBouncer configuration.  You can place any valid configuration in this section, but it must be in .yaml format.  


Currently the chart is set with the following default values.  Values the user should modify are in brackets (these brackets are not part of the yaml file and should not be included in the modifications).  However all should be modified according to user requirements:
```
config:
  adminUser: [pgbouncerAdmin]
  adminPassword: ["Google54321!"]
  authUser: [pgbouncer_auth_user]
  authPassword: Google543211
  listen_addr: "*"
  listen_port: 5432
  databases:
    postgres:
      host: [10.3.1.17]
      port: [5432]
    tpcc:
      host: [10.3.1.17]
      port: [5432]
  pgbouncer:
    auth_type: md5
    auth_query: SELECT p_user, p_password FROM public.lookup($1)
    pool_mode: transaction
    max_client_conn: 7500
    min_pool_size: 15
    default_pool_size: 20
    reserve_pool_size: 10
    reserve_pool_timeout: 3
    server_lifetime: 300
    server_idle_timeout: 60
    server_connect_timeout: 5
    server_login_retry: 1
    query_timeout: 60
    query_wait_timeout: 60
    client_idle_timeout: 60
    client_login_timeout: 60
    client_tls_sslmode: disable
    server_tls_sslmode: prefer
    ignore_startup_parameters: extra_float_digits
    track_extra_parameters: search_path,IntervalStyle
    max_prepared_statements: 200
    application_name_add_host: 1
  userlist:
    test_user: "SCRAM-SHA-256$4096:wIiyxsACoIe3lyFlM8vqMgdFvE+FtmXhe1pBkH/Mkt4=$DB2aQSCTgL03/buI1oYt7MbrWK5tF1rYSx8/0MdQvhc=:H3nYnTbcuo6Bq6I2Fxj6BH/FUIM+VkIRXmy8o6qQrg8="

```