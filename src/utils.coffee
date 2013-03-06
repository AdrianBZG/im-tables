do ->

    # Simple tree-walker
    walk = (obj, f) ->
      for own k, v of obj
        if _.isObject v
          walk v, f
        else
          f obj, k, v

    # Thorough deep cloner.
    copy = (obj) ->
      return obj unless _.isObject obj
      dup = if _.isArray(obj) then [] else {}
      for own k, v of obj
        if _.isArray v
          duped = []
          duped.push copy x for x in v
          dup[k] = duped
        else if not _.isObject v
          dup[k] = v
        else
          dup[k] = copy v
      dup

    ##
    # Very naïve English word pluralisation algorithm
    #
    # @param {String} word The word to pluralise.
    # @param {Number} count The number of items this word represents.
    ##
    pluralise = (word, count) ->
        if count is 1
            word
        else if word.match /(s|x|ch)$/
            word + "es"
        else if word.match /[^aeiou]y$/
            word.replace /y$/, "ies"
        else
            word + "s"

    # TODO: unit tests
    numToString = (num, sep, every) ->
        rets = []
        i = 0
        chars =  (num + "").split("")
        len = chars.length
        groups = _(chars).groupBy (c, i) -> Math.floor((len - (i + 1)) / every).toFixed()
        while groups[i]
            rets.unshift groups[i].join("")
            i++
        return rets.join(sep)


    getParameter = (params, name) ->
        _(params).chain().select((p) -> p.name == name).pluck('value').first().value()

    modelIsBio = (model) -> !!model?.classes['Gene']

    requiresAuthentication = (q) -> _.any q.constraints, (c) -> c.op in ['NOT IN', 'IN']

    getOrganisms = (query, cb) ->
        restrictedOrganisms = (c.value for c in query.constraints when c.path.match(/(o|O)rganism/))
        if restrictedOrganisms.length
            cb(restrictedOrganisms)
        else
            toRun = query.clone()
            orgs = []
            nodes = (toRun.getPathInfo(v).getParent() for v in toRun.views)
            onodes = (n for n in nodes when (n.toPathString() is "Organism" or n.getType().fields["organism"]?))
            onodes2 = (if n.toPathString() is "Organism" then n else n.append("organism") for n in onodes)
            newView = ("#{n.toPathString()}.shortName" for n in onodes2)
            toRun.views = _.uniq(newView)
            if toRun.views.length
                toRun.sortOrder = []
                promise = toRun.rows (rows) ->
                    for row in rows
                        orgs = orgs.concat(row)
                    cb _.uniq(orgs)
                promise.fail ->
                    cb orgs
            else
                cb orgs

    scope "intermine.utils", {
      copy, walk, getOrganisms, requiresAuthentication, modelIsBio,
      getParameter, numToString, pluralise
    }
            
