ifeq ($(shell uname -m) ,arm64)
	DOCKER_FLAGS += --platform linux/amd64
endif

TEST_APP_PATH = $(CURDIR)/test-app
CERTIFICATE_PATH = $(TEST_APP_PATH)/spec/fixtures/certificates
TRUSTED_CERTIFICATES_PATH = $(TEST_APP_PATH)/spec/fixtures/trusted_certificates

clean:
	rm -rf $(CERTIFICATE_PATH)
	rm -rf $(TRUSTED_CERTIFICATES_PATH)

test: build $(TRUSTED_CERTIFICATES_PATH) FORCE
	docker run $(DOCKER_FLAGS) --rm  -v=$(CERTIFICATE_PATH):/certificates -v=$(CURDIR)/radius:/etc/raddb -v=$(CURDIR)/radius/certs:/etc/raddb/certs -v=$(TRUSTED_CERTIFICATES_PATH):/etc/raddb/certs/trusted_certificates -p 1812-1813:1812-1813/udp -p 3000:3000 -p 9812:9812 --name govwifi-frontend-c govwifi-frontend /usr/bin/run-tests.sh

lint: build
	docker run $(DOCKER_FLAGS) --rm -v=$(CURDIR)/radius:/etc/raddb -v=$(CURDIR)/radius/certs:/etc/raddb/certs -p 1812-1813:1812-1813/udp -p 3000:3000 -p 9812:9812 govwifi-frontend /bin/sh -c "cd /healthcheck && bundle exec rubocop -d"

build: FORCE
	docker build --progress=plain $(DOCKER_FLAGS) -t govwifi-frontend .

serve: build $(TRUSTED_CERTIFICATES_PATH) FORCE
	# Declare the /etc/radius/certs mount explicity, despite being a subdir of /etc/radius because it is declared
	# as a volume in the Dockerfile and this prevents it being covered by the parent bind mount
	docker run $(DOCKER_FLAGS) --rm -it -v=$(CERTIFICATE_PATH):/certificates -v=$(CURDIR)/radius:/etc/raddb -v=$(CURDIR)/radius/certs:/etc/raddb/certs -v=$(TRUSTED_CERTIFICATES_PATH):/etc/raddb/certs/trusted_certificates -p 1812-1813:1812-1813/udp -p 3000:3000 -p 9812:9812 --name govwifi-frontend-c govwifi-frontend /usr/bin/run-local.sh

$(CERTIFICATE_PATH):
	mkdir -p $(CERTIFICATE_PATH)
	openssl req -x509 -newkey rsa:4096 -keyout $(CERTIFICATE_PATH)/root_ca.key -out $(CERTIFICATE_PATH)/root_ca.pem -sha256 -days 365 -nodes -subj '/CN=Root CA'
	openssl req -newkey 4096 -keyout $(CERTIFICATE_PATH)/intermediate_ca.key -outform pem -keyform pem -out $(CERTIFICATE_PATH)/intermediate_ca.req -nodes -subj '/CN=Intermediate CA'
	openssl x509 -req -CA $(CERTIFICATE_PATH)/root_ca.pem -CAkey $(CERTIFICATE_PATH)/root_ca.key -in $(CERTIFICATE_PATH)/intermediate_ca.req -out $(CERTIFICATE_PATH)/intermediate_ca.pem -extensions v3_ca -days 365 -CAcreateserial -extfile $(TEST_APP_PATH)/openssl.conf -CAserial $(CERTIFICATE_PATH)/intermediate.srl
	openssl req -newkey 4096 -keyout $(CERTIFICATE_PATH)/client.key -outform pem -keyform pem -out $(CERTIFICATE_PATH)/client.req -nodes -subj '/CN=Client'
	openssl x509 -req -CA $(CERTIFICATE_PATH)/intermediate_ca.pem -CAkey $(CERTIFICATE_PATH)/intermediate_ca.key -in $(CERTIFICATE_PATH)/client.req -out $(CERTIFICATE_PATH)/client.pem -extensions v3_client -days 365 -CAcreateserial -extfile $(TEST_APP_PATH)/openssl.conf -CAserial $(CERTIFICATE_PATH)/client.srl
	openssl req -newkey 4096 -keyout $(CERTIFICATE_PATH)/alt_intermediate_ca.key -outform pem -keyform pem -out $(CERTIFICATE_PATH)/alt_intermediate_ca.req -nodes -subj '/CN=Alternate Intermediate CA'
	openssl x509 -req -CA $(CERTIFICATE_PATH)/root_ca.pem -CAkey $(CERTIFICATE_PATH)/root_ca.key -in $(CERTIFICATE_PATH)/alt_intermediate_ca.req -out $(CERTIFICATE_PATH)/alt_intermediate_ca.pem -extensions v3_ca -days 365 -CAcreateserial -extfile $(TEST_APP_PATH)/openssl.conf -CAserial $(CERTIFICATE_PATH)/alt_intermediate.srl
	openssl req -newkey 4096 -keyout $(CERTIFICATE_PATH)/alt_client.key -outform pem -keyform pem -out $(CERTIFICATE_PATH)/alt_client.req -nodes -subj '/CN=Alternate Client'
	openssl x509 -req -CA $(CERTIFICATE_PATH)/alt_intermediate_ca.pem -CAkey $(CERTIFICATE_PATH)/alt_intermediate_ca.key -in $(CERTIFICATE_PATH)/alt_client.req -out $(CERTIFICATE_PATH)/alt_client.pem -extensions v3_client -days 365 -CAcreateserial -extfile $(TEST_APP_PATH)/openssl.conf -CAserial $(CERTIFICATE_PATH)/alt_client.srl

$(TRUSTED_CERTIFICATES_PATH): $(CERTIFICATE_PATH)
	mkdir -p $(TRUSTED_CERTIFICATES_PATH)
	cp $(CERTIFICATE_PATH)/root_ca.pem $(TRUSTED_CERTIFICATES_PATH)/root_ca.pem
	cp $(CERTIFICATE_PATH)/intermediate_ca.pem $(TRUSTED_CERTIFICATES_PATH)/intermediate_ca.pem
	cat $(CERTIFICATE_PATH)/client.pem $(CERTIFICATE_PATH)/intermediate_ca.pem > $(CERTIFICATE_PATH)/combined_client.pem
	cat $(CERTIFICATE_PATH)/alt_client.pem $(CERTIFICATE_PATH)/alt_intermediate_ca.pem > $(CERTIFICATE_PATH)/alt_combined_client.pem

FORCE:
