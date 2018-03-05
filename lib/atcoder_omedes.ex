defmodule AtCoderOmedes do
  require Logger
  @path Application.get_env :atcoder_omedes, :data_path, "data.csv"

  def run do
    prev_users = load()
    cur_users = get_users() 

    # Fetch users whose highest rating and color changed
    new_highest_users = cur_users
      |> Enum.map(fn {name, cur} ->
          %{^name => %{highest: prev_highest, rating: _}} = prev_users
          cond do
            prev_highest < cur.highest and color(prev_highest) != color(cur.highest) -> [name, color(cur.highest)]
            true -> nil
          end
        end)
      |> Enum.filter(& &1)
      |> Map.new(fn [k, v] -> {k, v} end)

    update cur_users
    IO.puts stringify new_highest_users
  end

  def update(users) do
    f = File.open! @path, [:write, :utf8]
    users
    |> Enum.map(fn {name, info} -> [name, info.rating, info.highest] end)
    |> CSV.encode
    |> Enum.each(&IO.write(f, &1))
  end

  def load do
    File.stream!(@path)
    |> CSV.decode!
    |> Enum.map(fn [name, cur, high] -> [
        name,
        %{rating: cur |> Integer.parse |> elem(0),
          highest: high |> Integer.parse |> elem(0)}
      ] end)
    |> Map.new(fn [name, info] -> {name, info} end)
  end

  def get_users do
    List.foldl get_pages(), %{}, fn(page, acc) ->
      Floki.find(page, "tr")
      |> Enum.map(fn(tr) ->
          case tr |> Floki.find("td") do
            [_, usertd, curtd, maxtd, _, _] -> [
              usertd |> Floki.find("span") |> Floki.text(),
              %{rating: curtd |> Floki.text() |> Integer.parse() |> elem(0),
                highest: maxtd |> Floki.text() |> Integer.parse() |> elem(0)}
            ]
            _ -> nil
          end
        end)
      |> Enum.filter(& &1)
      |> Map.new(fn [name, info] -> {name, info} end)
      |> Map.merge(acc)
    end
  end

  def get_pages, do: get_pages 3, [get_page(1), get_page(2)]
  # def get_pages(3, arr), do: arr # for testing
  def get_pages(index, [head | tail]) do
    Logger.info "fetching #{index}"
    case get_page(index) do
      ^head -> [head | tail]
      _ -> get_pages(index + 1, [get_page(index) | [head | tail]])
    end
  end

  def get_page(index) do 
    %{body: html} = HTTPoison.get! "http://atcoder.jp/ranking?p=#{index}"
    html
  end

  def color(rating) do
    cond do
      rating >= 2800 -> :red
      rating >= 2400 -> :orange
      rating >= 2000 -> :yellow
      rating >= 1600 -> :blue
      rating >= 1200 -> :cyan
      rating >=  800 -> :green
      rating >=  400 -> :brown
      true -> :gray
    end
  end

  def stringify(users) do
    color_str = [:red, :orange, :yellow, :blue, :cyan, :green]
    |> Enum.map(fn c ->
        case users |> Map.values |> Enum.count(& &1 == c) do
          0 -> nil
          n -> "#{n} #{c |> Atom.to_string}"
        end
      end)
    |> Enum.filter(& &1)
    |> Enum.join(", ")

    """
    AGC999 has ended!
    There are new #{color_str} coders!
    Kudos to #{users |> Map.keys |> Enum.join(", ")} 🎉🎉🎉
    """
  end
end