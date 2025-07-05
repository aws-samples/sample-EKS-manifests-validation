#This is just a Example dockerfile
#checkov:skip=CKV_DOCKER_7
#checkov:skip=CKV_DOCKER_2
#checkov:skip=CKV_DOCKER_3

FROM bitnami/node
RUN mkdir -p /usr/src/calc
WORKDIR /usr/src/calc
COPY . .
RUN npm install
# EXPOSE 3000
CMD [ "node", "app.js" ]
