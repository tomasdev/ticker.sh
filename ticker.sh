#!/bin/bash
set -e

printable_colours=256

LANG=C
LC_NUMERIC=C

SYMBOLS=("$@")

if ! $(type jq > /dev/null 2>&1); then
  echo "'jq' is not in the PATH. (See: https://stedolan.github.io/jq/)"
  exit 1
fi

if [ -z "$SYMBOLS" ]; then
  echo "Usage: ./ticker.sh AAPL MSFT GOOG BTC-USD"
  exit
fi

FIELDS=(symbol marketState regularMarketPrice regularMarketChange regularMarketChangePercent \
  preMarketPrice preMarketChange preMarketChangePercent postMarketPrice postMarketChange postMarketChangePercent)
API_ENDPOINT="https://query1.finance.yahoo.com/v7/finance/quote?lang=en-US&region=US&corsDomain=finance.yahoo.com"

if [ -z "$NO_COLOR" ]; then
  : "${COLOR_BOLD:=\e[1;37m}"
  : "${COLOR_GREEN:=\e[32m}"
  : "${COLOR_RED:=\e[31m}"
  : "${COLOR_DARKGRAY:=\e[90m}"
  : "${COLOR_RESET:=\e[00m}"
  : "${BG_COLOR_RED:=\e[41m}"
  : "${BG_COLOR_GREEN:=\e[42m\e[30m}"
  : "${BG_COLOR_CYAN:=\e[46m\e[30m}"
fi

symbols=$(IFS=,; echo "${SYMBOLS[*]}")
fields=$(IFS=,; echo "${FIELDS[*]}")

results=$(curl --silent "$API_ENDPOINT&fields=$fields&symbols=$symbols" \
  | jq '.quoteResponse .result')

query () {
  echo $results | jq -r ".[] | select(.symbol == \"$1\") | .$2"
}

for symbol in $(IFS=' '; echo "${SYMBOLS[*]}"); do
  marketState="$(query $symbol 'marketState')"

  if [ -z $marketState ]; then
    printf 'No results for symbol "%s"\n' $symbol
    continue
  fi

  preMarketChange="$(query $symbol 'preMarketChange')"
  postMarketChange="$(query $symbol 'postMarketChange')"

  if [ $marketState == "PRE" ] \
    && [ $preMarketChange != "0" ] \
    && [ $preMarketChange != "null" ]; then
    nonRegularMarketSign="${BG_COLOR_RED}MARKET CLOSED$COLOR_RESET"
    price=$(query $symbol 'preMarketPrice')
    diff=$preMarketChange
    percent=$(query $symbol 'preMarketChangePercent')
  elif [ $marketState != "REGULAR" ] \
    && [ $postMarketChange != "0" ] \
    && [ $postMarketChange != "null" ]; then
    nonRegularMarketSign="${BG_COLOR_CYAN}MARKET OPEN?$COLOR_RESET"
    price=$(query $symbol 'postMarketPrice')
    diff=$postMarketChange
    percent=$(query $symbol 'postMarketChangePercent')
  else
    nonRegularMarketSign="${BG_COLOR_GREEN}MARKET OPEN$COLOR_RESET"
    price=$(query $symbol 'regularMarketPrice')
    diff=$(query $symbol 'regularMarketChange')
    percent=$(query $symbol 'regularMarketChangePercent')
  fi

  if [ "$diff" == "0" ]; then
    color=
  elif ( echo "$diff" | grep -q ^- ); then
    color=$COLOR_RED
  else
    color=$COLOR_GREEN
  fi

  printf "%-10s$COLOR_BOLD%8.2f$COLOR_RESET" $symbol $price
  printf "$color%10.2f%12s$COLOR_RESET" $diff $(printf "(%.2f%%)" $percent)
  printf " %b\n" "$nonRegularMarketSign"
done

NOW=$(date +"%r")
printf "${COLOR_DARKGRAY}Last updated: %s$COLOR_RESET" "$NOW"
