#!/bin/sh
case "$1" in
  LONG_BIT) echo 64 ;;
  PAGE_SIZE|PAGESIZE) echo 4096 ;;
  _NPROCESSORS_ONLN) nproc ;;
  *) echo "" ;;
esac
