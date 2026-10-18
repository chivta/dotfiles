#!/bin/bash
exec bash "$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)/scaffold/amo_cms.sh"
