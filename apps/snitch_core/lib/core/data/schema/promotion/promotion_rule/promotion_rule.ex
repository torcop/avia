defmodule Snitch.Data.Schema.PromotionRule do
  @moduledoc """
  Models `rules` for a promotion.

  __Promotion rules__ are a set of conditions that the `payload`
  has to meet, to be eligible for the promotion.
  """
  use Snitch.Data.Schema
  alias Snitch.Data.Schema.Promotion

  @type t :: %__MODULE__{}

  @doc """
  Checks if the supplied order meets the condition specified
  in the supplied rule.
  """
  @callback eligible(order :: Order.t(), rule :: __MODULE__.t()) ::
              true | {false, reason :: String.t()}

  @doc """
  Returns the name of the rule.
  """
  @callback rule_name() :: name :: String.t()

  schema "snitch_promotion_rules" do
    field(:name, :string)
    field(:module, PromotionRuleEnum)
    field(:preferences, :map)

    # associations
    belongs_to(:promotion, Promotion, on_replace: :delete)

    timestamps()
  end

  @required_params ~w(name module)a
  @optional_params ~w(preferences promotion_id)a
  @create_params @required_params ++ @optional_params

  @doc """
  Returns a changeset for `PromotionRule.t()`.

  This function has been explicitly created to be used with while creating
  `promotion rule` with a promotion via the `cast_assoc` function.
  ### See
  `Promotion.rule_update_changeset/2`

  To create rule explicitly without `cast_assoc` use `create_changeset/2`.
  """
  def changeset(%__MODULE__{} = rule, params) do
    rule
    |> cast(params, @create_params)
    |> validate_required(@required_params)
    |> common_changeset()
  end

  def create_changeset(%__MODULE__{} = rule, params) do
    rule
    |> cast(params, @create_params)
    |> validate_required([:promotion_id | @required_params])
    |> common_changeset()
  end

  ############################ private functions ######################

  defp common_changeset(changeset) do
    changeset
    |> unique_constraint(:name)
    |> foreign_key_constraint(:promotion_id)
    |> validate_preference_with_target()
  end

  defp validate_preference_with_target(%Ecto.Changeset{valid?: true} = changeset) do
    with {:ok, preferences} <- fetch_change(changeset, :preferences),
         {:ok, module} <- fetch_change(changeset, :module) do
      preference_changeset = module.changeset(struct(module), preferences)
      add_preferences_change(preference_changeset, changeset)
    else
      :error ->
        changeset

      {:error, message} ->
        add_error(changeset, :module, message)
    end
  end

  defp validate_preference_with_target(changeset), do: changeset

  defp add_preferences_change(%Ecto.Changeset{valid?: true} = pref_changeset, changeset) do
    data = pref_changeset.changes
    put_change(changeset, :preferences, data)
  end

  defp add_preferences_change(pref_changeset, changeset) do
    additional_info =
      pref_changeset
      |> traverse_errors(fn {msg, opts} ->
        Enum.reduce(opts, msg, fn {key, value}, acc ->
          String.replace(acc, "%{#{key}}", to_string(value))
        end)
      end)

    add_error(changeset, :preferences, "invalid_preferences", additional_info)
  end
end