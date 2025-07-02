#!/bin/bash

dd if=./boot of=/dev/da0 bs=512 count=1 oflag=sync status=progress
gpart add -s 100M -t '!0x5a' da0
dd if=./stage1 of=/dev/da0s1 bs=512 count=1 oflag=sync status=progress
