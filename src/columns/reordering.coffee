scope 'intermine.messages.results', {
    ReorderHelp: 'Drag the columns to reorder them'
}

do ->

    class ColumnAdder extends intermine.query.ConstraintAdder
        className: "form node-adder btn-group"

        initialize: (query) ->
            super(query)
            @chosen = []

        handleChoice: (path) =>
            if path in @chosen
                @chosen = _.without @chosen, path
            else
                @chosen.push(path)
            @applyChanges()
            $b = @$('.btn-chooser')
            $b.button('toggle') if $b.is('.active')

        handleSubmission: (e) =>
            e.preventDefault()
            e.stopPropagation()
            @applyChanges()

        applyChanges: () ->
            @query.trigger 'column-orderer:selected', @chosen
            @reset()

        refsOK: false
        multiSelect: true

        isDisabled: (path) => path.toString() in @query.views

        render: () ->
            super()
            @$('input').remove()
            @$('.btn-chooser > span').text intermine.messages.columns.FindColumnToAdd
            this

    class ViewNode extends Backbone.Model

        initialize: ->
          unless @has 'isNew'
            @set isNew: false
          unless @has 'replaces'
            @set replaces: []
            
        addPath: (path) ->
          # using concat instead of push means we trigger 'change'
          @set replaces: @get('replaces').concat [path]

        getViews: -> if @get('replaces').length then @get('replaces') else [ @get('path') ]

    class NewViewNodes extends Backbone.Collection
        model: ViewNode

        close: ->
          @off()
          @each (vn) -> vn.off(); vn.destroy()

    class ColumnsDialogue extends Backbone.View
        tagName: "div"
        className: "im-column-dialogue modal fade"
        
        initialize: (@query, @columnHeaders) ->
          @columnHeaders ?= new Backbone.Collection
          @sortOpts = new Backbone.Model
          @sortOrder = new intermine.columns.collections.SortOrder
          @sortPossibles = new intermine.columns.collections.PossibleOrderElements
          @newView = new NewViewNodes()

          @sortOrder.on 'add', @addSortElement
          @sortPossibles.on 'add', @addPossibleSortElement

          @sortOpts.on 'change:onlyInView', (m, only) =>
            @sortPossibles.each (m) -> m.trigger 'only-in-view', only
          @sortOpts.on 'change:filterTerm', (m, re) =>
            @sortPossibles.each (m) -> m.trigger 'filter', re

          @sortOrder.on 'destroy', (m) =>
            @sortPossibles.add {path: m.get('path'), @query}

          @newView.on 'add remove change', @drawOrder, @
          @newView.on 'destroy', (nv) => @newView.remove(nv)

          @query.on 'column-orderer:selected', (paths) =>
            for path in paths
              pstr = path.toString()
              if @query.isOuterJoined(pstr)
                ojgs = @newView.filter( (nv) -> nv.get('isOuterJoined') )
                               .filter( (nv) -> !!pstr.match(nv.get('path').toString()) )
                ojg = _.last(_.sortBy(ojgs, (nv) -> nv.get('path').descriptors.length))
                ojg.addPath(@query.getPathInfo(pstr))
              else
                @newView.add {path: @query.getPathInfo(pstr), isNew: true}

        html: intermine.columns.snippets.ColumnsDialogue

        render: ->
          @$el.append @html
          @initOrdering()
          @initSorting()

          @sortOpts.set onlyInView: true
          @$('i.im-sorting-help').popover
            placement: (popover) ->
              $(popover).addClass 'bootstrap'
              'left'
            trigger: 'hover'
            html: true
            title: intermine.messages.columns.SortingHelpTitle
            content: intermine.messages.columns.SortingHelpContent

          @$('.nav-tabs li a').each (i, e) =>
              $elem = $(e)
              $elem.data target: @$($elem.data("target"))

          this

        events:
            'hidden': 'onHidden'
            'click .btn-cancel': 'hideModal'
            'click .btn-primary': 'applyChanges'
            'click .nav-tabs li a': 'changeTab'
            'change input.im-only-in-view': 'onlyShowOptionsInView'
            'change .im-sortables-filter': 'filterSortables'
            'keyup .im-sortables-filter': 'filterSortables'
            'sortupdate .im-reordering-container': 'updateOrder'

        onHidden: (e) ->
          return false unless @el is e?.target
          @remove()
        
        remove: ->
          @newView.close()
          delete @newView
          delete @columnHeaders
          @$el.empty()
          @undelegateEvents()
          @off()
          super()

        getFilterTerm: (e) ->
          $input = $ e.currentTarget
          term = $input.val()
          return unless term
          pattern = term.split(/\s+/).join('.*')
          new RegExp(pattern, 'i')

        filterSortables: (e) ->
          @sortOpts.set filterTerm: @getFilterTerm e

        onlyShowOptionsInView: (e) ->
          @sortOpts.set onlyInView: $(e.currentTarget).is ':checked'

        changeTab: (e) -> $(e.target).tab("show")

        initOrdering: ->
          @newView.reset(model.toJSON() for model in @columnHeaders.models)
          console.log @columnHeaders, @newView
          @drawOrder()
          @drawSelector()

        drawOrder: ->
          colContainer = @$ '.im-reordering-container'
          colContainer.empty()
          colContainer.tooltip
            title: intermine.messages.results.ReorderHelp
            placement: intermine.utils.addStylePrefix 'top'

          @newView.each (model) =>
            view = new intermine.columns.views.ViewElement {model}
            colContainer.append view.render().el

          colContainer.sortable
            items: 'li.im-reorderable'
            axis: 'y'
            forcePlaceholderSize: true
            placeholder: 'im-resorting-placeholder'


        drawSelector: ->
            nodeAdder = @$ '.node-adder'
            ca = new ColumnAdder(@query)
            nodeAdder.empty().append ca.render().el

        updateOrder: (e, ui) ->
            # The update event doesn't just tell us what has changed, so we have read the 
            # order out of the DOM. Urgh.
            lis = @$ '.im-view-element'
            byEl = (el) -> (nv) -> nv.el is el
            reorderedState = (@newView.find byEl el for el in lis.get())
            debugger unless reorderedState.length
            @newView.reset reorderedState

        sortingPlaceholder: """
            <div class="placeholder">
                Drop columns here.
            </div>
        """

        makeSortOrderElem: (model) ->
          possibles = @sortPossibles
          soe = new intermine.columns.views.OrderElement {model, possibles}
          soe.render().el

        makeSortOption: (model) ->
          option = new intermine.columns.views.PossibleOrderElement {model, @sortOrder}
          option.render().el

        initSorting: ->
          container = @$('.im-sorting-container').empty().append(@sortingPlaceholder)
          @$('.im-sorting-container-possibilities').empty()

          container.sortable()
          container.parent().droppable
            drop: (event, ui) -> $(ui.draggable).trigger 'dropped'

          @buildSortOrder()
          @buildPossibleSortOrder()

        buildSortOrder: ->
          @sortOrder.reset []

          for so, i in (@query.sortOrder or [])
            {path, direction} = so
            @sortOrder.add new intermine.columns.SortOrder
              path: @query.getPathInfo path
              direction: direction

        buildPossibleSortOrder: ->
          @sortPossibles.reset []

          isSorted = (v) => @query.getSortDirection v
          isOuter = (v) => @query.isOuterJoined v
          inView = (v) => "#{ v }" in @query.views

          test0 = (path) -> not isSorted(path) and not isOuter(path)
          test1 = (p) -> p.isAttribute() and not inView(p) and not isSorted(p)

          for path in @query.views when test0 path
            @sortPossibles.add {path, @query}

          for n in @query.getQueryNodes() when not isOuter n
            for path in n.getChildNodes() when test1 path
              @sortPossibles.add {path, @query}
        
        addSortElement: (m) =>
          container = @$ '.im-sorting-container'
          elem = @makeSortOrderElem m
          container.append elem

        addPossibleSortElement: (m) =>
          possibilities = @$ '.im-sorting-container-possibilities'
          elem = @makeSortOption m
          possibilities.append elem

        hideModal: -> @$el.modal 'hide'

        showModal: -> @$el.modal show: true

        applyChanges: (e) ->
            if @$('.im-reordering').is('.active')
                @changeOrder(e)
            else
                @changeSorting(e)

        changeOrder: (e) ->
            newViews = _.flatten @newView.map (v) -> v.getViews()
            @hideModal()
            @query.select(newViews)

        changeSorting: (e) ->
            lis = @$('.im-sorting-container li')
            newSO = lis.map( (i, e) -> {path: $(e).data('path'), direction: $(e).data("direction")}).get()
            @hideModal()
            @query.orderBy(newSO)

    scope "intermine.query.results.table", {ColumnsDialogue}
