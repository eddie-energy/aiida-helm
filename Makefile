RELEASE_NAME?=demo-aiida
NAMESPACE?=aiida

install:
	helm install $(RELEASE_NAME) -n $(NAMESPACE) chart

upgrade:
	helm upgrade -n $(NAMESPACE) $(RELEASE_NAME) chart

uninstall:
	helm uninstall -n $(NAMESPACE) $(RELEASE_NAME)

seal-secret:
	yq eval '.$(VALUE)' ./chart/values.yaml | tr -d '\n'| kubeseal \
			--controller-namespace $(NAMESPACE) \
			--controller-name sealed-secrets-controller-$(NAMESPACE) \
			--raw \
			--namespace $(NAMESPACE) \
			--name $(RELEASE_NAME)-$(SECRET_NAME) | \
			xargs \-I{} yq eval -i '.$(VALUE) = "{}"' \
			./chart/values.yaml

create-ghcr-secret:
	kubectl -n $(NAMESPACE) create secret docker-registry ghcr-secret \
	  --docker-server=ghcr.io \
	  --docker-username=${CR_USERNAME} \
	  --docker-password=${CR_PAT}
