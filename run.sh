#!/bin/bash

MESHBLU_UUID='546a34c2-849f-4652-b273-18055bc53b84'
MESHBLU_TOKEN='723dd594b16e36b47537baf4edaa6e2f995c1dcd'
OCTOBLU_OAUTH_URL='http://oauth.octoblu.dev'

LIB_CLIENT_ID='e73058c4bf7c9cb95007'
LIB_CLIENT_SECRET='8479e154df17ad2ddc4aa835618171ceb10ded08'
LIB_CALLBACK_URL='http://endo-lib.octoblu.dev:3000/auth/api/callback'

SERVICE_URI="http://192.168.100.34:3000"

MESHBLU_PRIVATE_KEY='MIIEpQIBAAKCAQEAo09/fTNmC1ov57Zv/3CBIfqet1todgnRuatFrce6u0+sQCj44IYBR3kStniFute1y5eDClu6Qj8+ZqtSIl+neWBZB0jLZejI5uQcySuFJY+Ouh9+T+0wrjSeTR08AIRDdzWauFHa0Gvg+wu9mbPT0zPTF1BZqzEuub9RdysaoRT41ucejDcIyFro85xEVppMZhzFcqYfmSlBlESlz5e8eZ8Y8kwTJ7mxfl1SCipX4PN3dFLGgw+W5HC1Lhis/rjWvKfU+kb7skejDHvEQNiqdTnPnOSegUQw3yfxbDXZsAKQzso+z0okeeGLJO2e2tKasc3TE0ZWBdPzOsEy5WuztwIDAQABAoIBAQCQ3t/wl9zpKysd+UgnKI1VMDcF3u+u7oz+kQHx5CExMr9R90a4HggaeDvyZL30/pBFt/VGBhMX23SmrUniNkqhsKepf5j3oWY+9JLYnmOx60SotXFew8GQeBsJu2pT5wDWSlYjNnHOvDRLX6HlLJI3ZFzY7K1u4OVbX22MMk+gHkb5FxYR6/UrFH+2Y9lfF0TQEl7+rKDnh/pRHjgZ4J4n4V2exSIWthCT/I5r71zaFvZZxy0v3Kj4K1jfBl80uQ4n7vcx4lm7NXFMKBGMNS/teljayP//iBm5F6DsAIWEJ2rABj8bPE8JZHAYs08FUMh9eDlwTxrgmUD9LHo8ssXJAoGBAOIeLRHO3kirRll122xx8rBrneRHr5XPTmXzlmINokmPJENxjW4wg9PQs0CegUDYIpu+uf8qD6+BS1bj8mmol6bcDjyNv0+MzLvGZ9F19JCvwqA5xeqz5Ipz5K/GKB1xJ8tbIU24wqy8E+eSdiCO7AAfg21fGB9Qn4GCMoJ2AI2VAoGBALjkeoV1Zkgbl+tEZ8tqCzpHaKsmtgWHCvKyVOEXJeY2UA/H/P8+pD118pcR9J9PAbmjFkaI+ao89ne1c0OeKwCx7qsaklbS5eq0rAH05Ej2xydVMnGXKt2Q9EbykuejUpnp3DW52EFtSQCSN+jbF1ZE8kAmPBsHh7STZAS95nEbAoGAJ5oNXq8Sczu8CHMByQ5z6L4QWyjK8bvrCSQOVIH6yFNPkJhUotXQYMqOemTIUmkINqrCvJPLR3unjEJD9IlYdhrYS3av6OjJ+qEXEbJM8QI3XgSAS0jSYAVIKhjUccOdqpn9TTVsswAFpGscUTt2zda3F/KtsN5X8UCyQ/MSybkCgYEAr/AisrqLcNRpFORMDKHFO1jWPf8hOFNP1LBj2qlnVBCc0NeSZOSb7yw8gwsAB1RsJNUPDmGrihZmxnTw0QhCjW/D2Cf51wrq5BO2lkoNrWy/CCunS7X4gUw9VwHfTvL4WCPUe390TJYM4LFC6J8LLvl+uBJqIaJhvTB//Y8jKL8CgYEAiA3e0MyxshTvLfSPYk9yNe2VuNzCU6b6bLY6y2WoTsh3zbvjHb3l4jQTsRDDjG/YwAOmw/qPVbl5cj62vp9A34oLeDPH6qeB7/2lbns46A+DEHJYeYJRhH0uUhTML/kZ9fqD2iGz7vXso1FwzzIFqflFI/FRrNsUAN4pzorljJU='
MESHBLU_SERVER="meshblu.octoblu.dev"
MESHBLU_PORT="443"
MESHBLU_PROTOCOL="https"

run_mocha(){
  mocha
}

run_yo(){
  local skip_install="$1"
  local args=" --skip_install "


  if [ "$skip_install" == "false" ]; then
    args=""
  fi

  yo endo \
    --force \
    --github-user octoblu \
    $args
}

remove_non_lib_files() {
  rm command.*
  rm -rf schemas
  rm src/strategies/api-strategy.coffee
  rm src/message-handlers.coffee
}

main(){
  local debug="$DEBUG"
  local skip_install="$SKIP_INSTALL"
  run_yo "$skip_install" \
  && remove_non_lib_files \
  && run_mocha
}

main $@
