# Gitolite-Kubernetes

## Copyright

(c) 2024 Mark Himsley

## Description

This repository contains a Docker build file to create an Open Container Initiative (OCI) image containing Gitolite and an OpenSSH server.

This repository also contains example Kubernetes [kubectl kustomize](https://kubernetes.io/docs/reference/kubectl/generated/kubectl_kustomize/) manifest fragments to create a Gitolite instance  accessed by public-key auth SSH, running as a [StatefulSet](https://kubernetes.io/docs/concepts/workloads/controllers/statefulset/) in a [Kubernetes cluster](https://kubernetes.io/docs/concepts/overview/components/).

Please make sure you are familiar with [Gitolite](https://gitolite.com/gitolite/index.html), [OpenSSH server](https://man.openbsd.org/sshd.8), [building and publishing OCI images with Docker](https://docs.docker.com/get-started/docker-concepts/building-images/build-tag-and-publish-an-image/) and [Kubernetes](https://kubernetes.io/).

The OCI image will be useful for self-hosting your private git repositories. It should be more secure than running a [bare metal server](https://en.wikipedia.org/wiki/Bare-metal_server) or [virtual machine](https://en.wikipedia.org/wiki/Virtual_machine) running Gitolite.

The image could be run as a stand-alone Docker container, but I'm not interested in that.

## Use the packaged OCI image

An image has been published to GitHub's Container registry [`ghcr.io/himslm01/gitolite:v3.6.13`](https://github.com/himslm01/gitolite-kubernetes/pkgs/container/gitolite).

## Build the OCI image

The [`Dockerfile`](src/Dockerfile) and entry point shell script [`entrypoint.sh`](src/entrypoint.sh) are located in the `src` folder.

I assume you'll be pushing the built OCI image to a local repository, so these are the commands you'll need to run from a shell at the root of this repository.

```code
docker build -t <your-repository>/gitolite:v3.6.13 src/
docker push <your-repository>/gitolite:v3.6.13
```

## Deploying to Kubernetes

This assumes that you have persistent storage available that you can make a `PersistentVolume` point to, via NFS or something similar.

* Make a new kubectl kustomize override directory by copying the directory `override/example` and its contents to a new directory within the `override` directory.
  ```code
  pushd src/override
  cp -va example foo
  popd
  ```
* Create or copy your ssh host keys into the `ssh` folder within your newly created override folder. See below for creating ssh host keys.
* If you have built your own OCI image and pushed it to your repository, edit the file `kustomization.yaml` to replace the current values for `images/newName` and `images/newTag` with your repository, image name, and tag.
* Edit the file `env.properties` to set the four environment variables for:
  * `GIT_UID` the user ID that the `git` user will run as in your container
  * `GIT_GID` the group ID that the `git` user will run as in your container
  * `GITOLITE_ADMIN_PUBKEY` only used when creating a new set of git repositories managed by Gitolite, this is the first public key which will have access to administer the Gitolite instance. See the [`-pk`](https://gitolite.com/gitolite/quick_install.html) option
  * `GITOLITE_ADMIN_USERNAME` only used when creating a new set of git repositories managed by Gitolite, this is the name of the first public key. See [`yourname`](https://gitolite.com/gitolite/quick_install.html) in the [`-pk`](https://gitolite.com/gitolite/quick_install.html) option
* Edit the file `service-patch.yaml` to set the `loadBalancerIP` address for the `sshd` service.
* Edit the file `persistentVolume.yaml` to point to your storage.

These kubectl kustomize manifest fragments assume that you will deploy the Gitolite system into a new `namespace` called `gitolite`. If that is not the case then edit the files `kustomization.yaml` and `namespace.yaml` to set the namespace you will use.

Now you should be ready to deploy Gitolite into your Kubernetes cluster. Check that the kustomized yaml manifests are correct by running `kubectl kustomize` against your override folder.

```code
kubectl kustomize src/override/foo
```

When you believe the output is correct, apply that to your kubernetes cluster.

```code
kubectl kustomize src/override/foo | kubectl apply -f - --context <cluster-name>
```

## Create SSH host keys

The OCI image runs an SSH server. The SSH config file and host keys must be provided to the container at run time. They are stored within a `secret` in Kubernetes and mounted as a `volume` onto the container.

The example kubernetes kustomize manifest fragments expect four key-pairs to be stored in the folder `ssh` in the override folder you create for your deployment.

If you need to create those keys you can do so using these commands.

```code
pushd src/override/foo/ssh
ssh-keygen -q -t dsa -N '' -f ssh_host_dsa_key
ssh-keygen -q -t ecdsa -b 521 -N '' -f ssh_host_ecdsa_key
ssh-keygen -q -t ed25519 -N '' -f ssh_host_ed25519_key
ssh-keygen -q -t rsa -b 4096 -N '' -f ssh_host_rsa_key
popd
```

## Migrating from running Gitolite on a bare metal or virtual machine

This repository was created to migrate an unmaintained VM running Gitolite into a Kubernetes cluster.

This assumes that:

* the user which Gitolite is running as on the bare metal or virtual machine is `git`
* the home directory of the `git` user is `~git`
* the repositories directory is at `~git/repositories` on the original server
* you have some persistent storage that can hold all of the repositories data and the other data held in the `~git` folder

### Migrate the repositories directory

In my instance I had, for many years, run Gitolite in a small VM with the repositories stored on a NAS mounted with NFS.

As described in the [odds and ends](https://gitolite.com/gitolite/odds-and-ends.html) page in the Gitolite documentation, it's okay to move the `repositories` folder to wherever you want and replace it with a symlink pointing to the new location. This is what I had done, with `repositories` being stored on a NAS, mounted onto a directory with autofs, and a symbolic link at `~git/repositories` pointing to that mount point.

### Migrate the rest of ~git

When the Gitolite VM was quiescent (I stopped the sshd service) I copied the following files and directories onto the NFS NAS server:

* `~git/.gitolite` directory
* `~git/.gitolite.rc` file
* `~git/projects.list` file
* `~git/.ssh` directory

```code
cd ~git
cp -var .gitolite .gitolite.rc projects.list .ssh /<NAS mount point>/
```

On the NAS server I ended up with `/export/git/home_git` and `/export/git/repositories`. This allowed me to have one Kubernetes PV mounting the `/export/git` directory, one Kubernetes PVC exposing that to the Gitolite pod, and use the `subPath: home_git` and `subPath: repositories` to mount those as volumes into the Gitolite container.

### the location of `gitolite-shell`

If the `gitolite-shell` on the source machine was not located at `/opt/gitolite/src/gitolite-shell`, as it is in this image, then you will need to edit `.ssh/authorized_keys` to replace the old location with `/opt/gitolite/src/gitolite-shell`.

My previous VM was based on Ubuntu and had the Gitolite deb package installed. Gitolite was installed in `/usr/shared/gitolite3/`. I had to edit `.ssh/authorized_keys`. Since I have quite a lot of keys I used vim's global edit function to replace all instances of `/usr/shared/gitolite3/gitolite-shell` with `/opt/gitolite/src/gitolite-shell`. The magic vim incantation was:

```code
:%s!/usr/shared/gitolite3/gitolite-shell!/opt/gitolite/src/gitolite-shell!g
```

## Running the OCI image

I am not interested in running the image on plain-old-Docker. But if you wanted to, you could run the OCI image as a local Docker container to host your Gitolite managed repositories in local Docker volumes.

```code
docker run \
 --rm \
 --name gitolite \
 --env GIT_UID=1001 \
 --env GIT_GID=1001 \
 --env "GITOLITE_ADMIN_PUBKEY=ssh-rsa AAAAB3NzaC1yc2...7HSYSw0r+ANk=" \
 --env GITOLITE_ADMIN_USERNAME=admin \
 --mount type=bind,src=$PWD/sshd,dst=/sshd,ro \
 --mount type=volume,src=gitolite-home,dst=/home/git \
 --mount type=volume,src=gitolite-repositories,dst=/repositories \
 --publish 2222:2222 \
 <your-repository>/gitolite:v3.6.13
```

Or you could run the OCI image as a local Docker container to host your Gitolite managed repositories in remote NFS accessible volumes.

```code
docker run \
 --rm \
 --name gitolite \
 --env GIT_UID=1001 \
 --env GIT_GID=1001 \
 --env "GITOLITE_ADMIN_PUBKEY=ssh-rsa AAAAB3NzaC1yc2...7HSYSw0r+ANk=" \
 --env GITOLITE_ADMIN_USERNAME=admin \
 --mount type=bind,src=$PWD/sshd,dst=/sshd,ro \
 --mount "type=volume,dst=/repositories,volume-driver=local,volume-opt=type=nfs,volume-opt=device=:/export/git/repositories,\"volume-opt=o=addr=nas.lan,rw,nosuid,noatime\"" \
 --mount "type=volume,dst=/home/git,volume-driver=local,volume-opt=type=nfs,volume-opt=device=:/export/git/home_git,\"volume-opt=o=addr=nas.lan,rw,nosuid,noatime,\"" \
 --publish 2222:2222 \
 <your-repository>/gitolite:v3.6.13
```

## Warranty

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
