_ = require 'underscore'

class Format

  constructor: (id, icon, needs = []) ->
    icon ?= id
    key = "export.description.#{ id.toUpperCase() }"
    _.extend this, {id, icon, key, needs}

  # Return true if this format has no requirements, or if at least
  # one of its required types are present.
  isSuitable: (availableTypes) ->
    return true if @needs.length is 0
    _.any @needs, (needed) -> availableTypes[needed]

# There are no good bio icons in the font-awesome
# set, but there are tickets to get them put in. Maybe
# one day soon these will work.
formats = [
  new Format('tsv'),
  new Format('csv'),
  new Format('xml'),
  new Format('json'),
  new Format('fasta', 'dna', ['Protein', 'SequenceFeature']),
  new Format('gff3', 'dna', ['SequenceFeature']),
  new Format('bed', 'dna', ['SequenceFeature']),
  new Format('fake', 'fake', ['Department'])
  new Format('fake_2', 'fake', ['Company'])
]

exports.getFormats = (availableTypes) ->
  (f for f in formats when f.isSuitable availableTypes)

exports.registerFormat = ({id, icons, needs}) ->
  formats.push new Format id, icons, needs
