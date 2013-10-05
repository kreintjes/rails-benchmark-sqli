module HomeHelper
  def link_to_amounts(path, *args)
    s = ""
    @amounts.each do |amount|
      s += link_to amount, self.send(path, *args, amount)
      s += " "
    end
    s.html_safe
  end

  def link_to_objects(path, *args)
    s = ""
    @objects.each do |obj|
      s += link_to obj.id, self.send(path, obj, *args)
      s += " "
    end
    s.html_safe
  end
end
