function draw(keys, remaining, previous, random) {
  var deck = (remaining.length ? remaining : keys).slice();
  var skip = deck.length > 1 ? deck.indexOf(previous) : -1;
  var index = Math.floor(random() * (deck.length - (skip < 0 ? 0 : 1)));
  if (skip >= 0 && index >= skip) index++;
  return { key: deck.splice(index, 1)[0], remaining: deck };
}
