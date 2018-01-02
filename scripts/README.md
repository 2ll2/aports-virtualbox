# image builder

This docker image has `mkimage.sh` setup to generate `lambda-linux-vbox.iso`
image.

To get started

```
$ cd aports-virtualbox/scripts/

$ docker build -t image-builder-virtualbox .
```

Go to the _parent_ directory containing `aports-virtualbox` tree.

```
$ docker run --rm -ti -v $(pwd):/home/builder/src -v /tmp:/tmp \
       image-builder-virtualbox /bin/su -l -s /bin/sh builder

e30e9cd62ad3:~$ sudo apk update

e30e9cd62ad3:~$ cd src/aports-virtualbox/scripts/

e30e9cd62ad3:~/src/aports-virtualbox/scripts$ mkdir /tmp/iso

e30e9cd62ad3:~/src/aports-virtualbox/scripts$ ./mkimage.sh \
       --tag virtualbox \
       --outdir /tmp/iso \
       --arch x86_64 \
       --repository http://dl-cdn.alpinelinux.org/alpine/v3.7/main \
       --extra-repository '@repo-virtualbox /home/builder/repo/virtualbox/v3.7/main' \
       --profile virtualbox
```

The generated ISO image is at `/tmp/iso/lambda-linux-vbox.iso`.
