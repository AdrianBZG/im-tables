Modal = require './modal'

Templates = require '../templates'
Messages = require '../messages'
Collection = require '../core/collection'
PathModel = require '../models/path'
ColumnManagerTabs = require './column-manager/tabs'
SelectListEditor = require './column-manager/select-list'

require '../messages/columns'

class OrderByModel extends PathModel

  constructor: ({path, direction}) ->
    super path
    @set {direction}

class SelectList extends Collection

  model: (p) => # Create a model, setting the index on the model itself.
    index = @size()
    model = new PathModel p
    model.set {index}
    return model

  comparator: 'index'

class OrderByList extends Collection

  model: (args) -> new OrderByModel args

module.exports = class ColumnManager extends Modal

  parameters: ['query']

  title: -> Messages.getText 'columns.DialogueTitle'

  primaryAction: -> Messages.getText 'columns.ApplyChanges'

  act: -> unless @state.get 'disabled'
    @query.select @getCurrentView() # select the current view.
    @resolve 'changed'

  stateEvents: ->
    'change:currentTab': @renderTabContent

  initialize: ->
    super
    # Populate the select list and sort-order with the current state of the
    # query.
    @selectList = new SelectList
    @rubbishBin = new SelectList
    for v in @query.views
      @selectList.add @query.makePath v
    @sortOrder = new OrderByList
    for {path, direction} in @query.sortOrder
      @sortOrder.add {direction, path: @query.makePath(path)}
    @listenTo @selectList, 'sort add remove', @setDisabled

  getCurrentView: -> @selectList.pluck 'path'

  setDisabled: ->
    currentView = @getCurrentView().join ' '
    initialView = @query.views.join(' ')
    @state.set disabled: (currentView is initialView) # no changes - nothing to do.

  initState: -> # open the dialogue with the default tab open, and main button disabled.
    @state.set disabled: true, currentTab: ColumnManagerTabs.TABS[0]

  renderTabs: ->
    @renderChild 'tabs', (new ColumnManagerTabs {@state}), @$ '.modal-body'

  renderTabContent: -> if @rendered
    main = switch @state.get('currentTab')
      when 'view' then new SelectListEditor {@query, @rubbishBin, collection: @selectList}
      else throw new Error "Cannot render #{ @state.get 'currentTab' }"
    @renderChild 'main', main, @$ '.modal-body'

  postRender: ->
    super
    @renderTabs()
    @renderTabContent()

  remove: ->
    @selectList.close()
    @rubbishBin.close()
    @sortOrder.close()
    super




