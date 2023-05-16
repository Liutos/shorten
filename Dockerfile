FROM swipl
COPY . /app
CMD ["swipl", "-g", "halt.", "-s", "/app/main.pl"]
