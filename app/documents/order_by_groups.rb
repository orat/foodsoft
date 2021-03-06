# encoding: utf-8
class OrderByGroups < OrderPdf
  include OrdersHelper

  # optimal value depends on the number of articles ordered on average by each
  #   ordergroup as well as the available memory
  BATCH_SIZE = 50

  attr_reader :order

  def filename
    I18n.t('documents.order_by_groups.filename', :name => order.name, :date => order.ends.to_date) + '.pdf'
  end

  def title
    I18n.t('documents.order_by_groups.title', :name => order.name,
      :date => order.ends.strftime(I18n.t('date.formats.default')))
  end

  def group_orders
    @group_orders ||= @order.group_orders.ordered
  end

  def body
    # Start rendering
    each_group_order do |group_order|
      down_or_page 15

      total = 0
      has_tolerance = false
      taxes = Hash.new {0}
      fc_markup_price = 0
      rows = []
      dimrows = []

      each_group_order_article_for(group_order) do |goa|
        has_tolerance = true if goa.order_article.price.unit_quantity > 1
        price = goa.order_article.price.fc_price(group_order.ordergroup)
        sub_total = price * goa.result
        total += sub_total
        taxes[goa.order_article.price.tax.to_f.round(2)] += goa.result * goa.order_article.price.fc_tax_price(group_order.ordergroup)
        fc_markup_price += goa.result * goa.order_article.price.fc_markup_price(group_order.ordergroup)
        rows <<  [goa.order_article.article.name,
                  number_to_currency(price),
                  goa.order_article.article.unit,
                  goa.tolerance > 0 ? "#{goa.quantity} + #{goa.tolerance}" : goa.quantity,
                  goa.result,
                  result_in_units(goa),
                  number_to_currency(sub_total),
                  goa.order_article.price.unit_quantity]
        dimrows << rows.length if goa.result == 0
      end
      next if rows.length == 0

      # total
      rows << [{content: I18n.t('documents.order_by_groups.sum'), colspan: 6}, number_to_currency(total), nil]
      # price details (old orders may not have these details set)
      price_details = []
      price_details << "#{Article.human_attribute_name :price} #{number_to_currency group_order.net_price}" if group_order.net_price > 0
      price_details << "#{Article.human_attribute_name :deposit} #{number_to_currency group_order.deposit}" if group_order.deposit.to_f > 0
      taxes.each do |tax, tax_price|
        price_details << "#{Article.human_attribute_name :tax} #{number_to_percentage tax} #{number_to_currency tax_price}" if tax_price > 0
      end
      price_details << "#{Article.human_attribute_name :fc_share_short} #{number_to_percentage group_order.ordergroup.markup_pct} #{number_to_currency fc_markup_price}" if fc_markup_price > 0
      rows << [{content: '  ' + price_details.join('; '), colspan: 7}]

      # table header
      rows.unshift I18n.t('documents.order_by_groups.rows').dup
      rows.first[4] = {content: rows.first[4], colspan: 2}
      rows.first[-1] = {image: "#{Rails.root}/app/assets/images/package-bg.png", scale: 0.6, position: :center}

      rows.each {|r| r[-1] = nil} unless has_tolerance

      text show_group(group_order.ordergroup), size: fontsize(13), style: :bold
      table rows, width: bounds.width, cell_style: {size: fontsize(8), overflow: :shrink_to_fit} do |table|
        # borders
        table.cells.borders = [:bottom]
        table.cells.border_width = 0.02
        table.cells.border_color = 'dddddd'
        table.rows(0).border_width = 1
        table.rows(0).border_color = '666666'
        table.rows(0).column(4).font_style = :bold
        table.row(rows.length-3).border_width = 1
        table.row(rows.length-3).border_color = '666666'
        table.row(rows.length-2).borders = []
        table.row(rows.length-1).borders = []

        # bottom row with price details
        table.row(rows.length-1).text_color = '999999'
        table.row(rows.length-1).size = fontsize(7)
        table.row(rows.length-1).padding = [0, 5, 0, 5]

        table.column(0).width = 200 # @todo would like to set minimum width here
        table.column(1).align = :right
        table.columns(2..4).align = :center
        table.columns(4..6).font_style = :bold
        table.columns(5..6).align = :right
        table.column(7).align = :center
        # dim columns not relevant for members
        table.column(3).text_color = '999999'
        table.column(7).text_color = '999999'
        # hide unit_quantity if there's no tolerance anyway
        table.column(7).width = has_tolerance ? 25 : 0

        # dim rows which were ordered but not received
        dimrows.each do |ri|
          table.row(ri).text_color = 'aaaaaa'
          table.row(ri).columns(0..-1).font_style = nil
        end
      end
    end

  end

  private

  def group_orders
    order.group_orders.ordered.
      joins(:ordergroup).order('groups.name').
      preload(:group_order_articles => {:order_article => [:article, :article_price]})
  end

  def each_group_order
    group_orders.find_each_with_order(batch_size: BATCH_SIZE) {|go| yield go }
  end

  def group_order_articles_for(group_order)
    goas = group_order.group_order_articles.to_a
    goas.sort_by!(&:id)
    goas
  end

  def each_group_order_article_for(group_order)
    group_order_articles_for(group_order).each {|goa| yield goa }
  end

end
