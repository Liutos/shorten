FROM swipl
COPY . /app
CMD ["swipl", "-g", "server(8080)", "/app/main.pl"]
