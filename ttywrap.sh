#!/bin/sh
stty columns 300
stty rows 100
tty
stty size
$1 $2 $3
