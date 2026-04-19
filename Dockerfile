FROM node:24-bookworm-slim AS builder

WORKDIR /app

# Install dependencies required by the translation script.
COPY package.json package-lock.json ./
RUN apt-get update \
	&& apt-get -y upgrade \
	&& rm -rf /var/lib/apt/lists/* \
	&& npm ci --ignore-scripts \
	&& npm cache clean --force

COPY languages ./languages
COPY script ./script

FROM gcr.io/distroless/nodejs24-debian12:nonroot

WORKDIR /app
COPY --from=builder /app /app

CMD ["script/translate.js"]