### A Pluto.jl notebook ###
# v0.19.8

using Markdown
using InteractiveUtils

# ╔═╡ 4474fd86-9496-44c7-a6bf-47194d7e8e12
begin
  using Pkg
  Pkg.activate(joinpath(@__DIR__, "..", ".."))
  Pkg.instantiate()
end

# ╔═╡ 86f5ae82-8207-416e-9e54-3f7b3ca87ecb
begin
  using MLJ
  import DataFrames
end

# ╔═╡ 5dad6a5d-e6e9-4ea0-9bca-7c69b794f8ce
md"# Tutorial 3"

# ╔═╡ 33691746-74ed-425d-b795-033f6f2a0674
md"""
An introduction to machine learning using MLJ and the Titanic
dataset. Explains how to train a simple decision tree model and
evaluate it's performance on a holdout set.
"""

# ╔═╡ aa49e638-95dc-4249-935f-ddf6a6bfbbdd
md"""
MLJ is a *multi-paradigm* machine learning toolbox (i.e., not just
deep-learning).
"""

# ╔═╡ b04c4790-59e0-42a3-af2a-25235e544a31
md"""
For other MLJ learning resources see the [Learning
MLJ](https://alan-turing-institute.github.io/MLJ.jl/dev/learning_mlj/)
section of the
[manual](https://alan-turing-institute.github.io/MLJ.jl/dev/).
"""

# ╔═╡ 1734e972-19e8-4d40-8af5-148d95ea2900
md"## Activate package environment"

# ╔═╡ 6f4d110c-7f0b-4e70-828a-4cc485149963
md"## Establishing correct data representation"

# ╔═╡ e5885e24-b17b-471b-ba1f-6363f43ec697
md"""
A ["scientific
type"](https://juliaai.github.io/ScientificTypes.jl/dev/) or
*scitype* indicates how MLJ will *interpret* data (as opposed to how
it is represented on your machine). For example, while we have
"""

# ╔═╡ d225419b-a250-425e-95ea-2955abd45275
typeof(3.14)

# ╔═╡ 606143a8-2fb6-4fb9-b1b3-dd47e367ba54
md"we have"

# ╔═╡ 61e19dbd-3513-4813-8d7e-8e449afd1c48
scitype(3.14)

# ╔═╡ 76750462-191b-43ac-a949-7f3bd292fe31
md"and also"

# ╔═╡ 5c2ec910-6444-4c53-8514-99938a2932db
scitype(3.143f0)

# ╔═╡ ddaf1934-1aba-4ede-a0de-1721c1bc2df2
md"In MLJ, model data requirements are articulated using scitypes."

# ╔═╡ ca482134-299b-459a-bca8-7eec7950fd82
md"Here are common \"scalar\" scitypes:"

# ╔═╡ c7a45cde-2f9b-47c9-9873-1b1430e635cc
html"""
<div style="text-align: left";>
	<img src="https://github.com/ablaom/MLJTutorial.jl/blob/dev/notebooks/01_data_representation/scitypes.png?raw=true">
</div>
"""

# ╔═╡ 96c58ce9-9b29-4c5e-b43e-d0ebe87da176
md"""
There are also container scitypes. For example, the scitype of any
vector is `AbstractVector{S}`, where `S` is the scitype of its
elements:
"""

# ╔═╡ 9d2f0b19-2942-47ac-9009-4cfb2012998f
scitype(["cat", "mouse", "dog"])

# ╔═╡ b90f3b7b-4de2-4a5c-abd3-cb77d7a79683
md"""
We'll be using [OpenML](https://www.openml.org/home) to grab the
Titanic dataset:
"""

# ╔═╡ 4f8ae143-4f76-4d45-879e-dc128f3db7b3
begin
  table = OpenML.load(42638)
  df0 = DataFrames.DataFrame(table)
  DataFrames.describe(df0)
end

# ╔═╡ 1d18aca8-11f4-4104-a367-9aa3c6cf34d0
md"The `schema` operator summarizes the column scitypes of a table:"

# ╔═╡ accd3a09-5371-45ab-bf32-94657e65284e
schema(df0) |> DataFrames.DataFrame  # converted to DataFrame for better display

# ╔═╡ 45dd887b-332e-48ff-9afd-65a5b5facac9
md"Looks like we need to fix `:sibsp`, the number of siblings/spouses:"

# ╔═╡ cc239a2b-2522-42c8-b6c8-54f5ed90a964
coerce!(df0, :sibsp => Count);

# ╔═╡ 4b4e8f45-6206-40f0-9292-fe822525fc77
md"""
And we'll regard `:survived`, our target variable, as ordered (the
first level is then considered the "false" class)
"""

# ╔═╡ 6e9599dd-e507-43e3-ae5e-4b83dcbc9675
begin
  coerce!(df0, :survived => OrderedFactor)
  levels(df0.survived)
end

# ╔═╡ 1e99474e-2fd8-4e7d-8a29-32f11452654a
md"""
The `:cabin` feature has a lot of missing values, and low frequency
for other classes:
"""

# ╔═╡ 39a7b366-0330-4abd-a5f1-151fcbe229a2
begin
  import StatsBase
  StatsBase.countmap(df0.cabin)
end

# ╔═╡ 940f1ee2-f54d-4fa1-81bc-2d5603785a09
md"""
We'll make `missing` into a bona fide class and group all the other
classes into one:
"""

# ╔═╡ 069f1237-eb21-43cb-9d87-1d1fbb0e3997
function class(c)
    if ismissing(c)
        return "without cabin"
    else
        return "has cabin"
    end
end

# ╔═╡ 1e97e00e-d895-49d3-b950-fddef2a1fb10
md"""
Shorthand syntax would be `class(c) = ismissing(c) ? "without cabin" :
"has cabin"`. Now to transform the whole column:
"""

# ╔═╡ 9e8fab47-3c20-4524-951b-64cb2a36c8e3
begin
  df0.cabin = map(class, df0.cabin)          # now a `Textual` scitype
  coerce!(df0, :class => Multiclass)
  schema(df0)
end

# ╔═╡ 8644107f-4b52-41ca-b0e6-441461cc8770
md"## Splitting into train and test sets"

# ╔═╡ 4de9e07c-06b8-41a4-8cb0-de601961bc02
md"""
Here we split off 30% of our observations into a
lock-and-throw-away-the-key holdout set, called `df_test`:
"""

# ╔═╡ 0dcee734-f115-41af-a87d-950c50fb2955
begin
  df, df_test = partition(df0, 0.7, rng=123)
  DataFrames.nrow(df)
end

# ╔═╡ 30eb5d8f-e6c4-4a50-8448-4bcb089096cd
DataFrames.nrow(df_test)

# ╔═╡ 937fe069-98c9-45dd-a012-a84240254fb6
md"## Cleaning the data"

# ╔═╡ fe8a8726-5047-4826-bbdd-9799f7bb2e60
md"Let's constructor an MLJ model to impute missing data using default hyper-parameters:"

# ╔═╡ f49bb16f-aeeb-4fcd-97a7-88e3af4f10ee
cleaner = FillImputer()

# ╔═╡ f94cdf23-d113-4386-b372-8c9866e51852
md"""
In MLJ a *model* is just a container for hyper-parameters associated
with some ML algorithm. It does not store learned parameters (unlike
scikit-learn "estimators").
"""

# ╔═╡ bde9148b-79c2-4033-8f3d-b82f1e7b6f7a
md"We now bind the model with training data in a *machine*:"

# ╔═╡ de5e2209-020b-4bce-ab04-579e5608ae53
machc = machine(cleaner, df)

# ╔═╡ 3ac76fef-0379-4d32-86cf-35420d9e6995
md"""
And train the machine to store learned parameters there (the column
modes and medians to be used to impute missings):
"""

# ╔═╡ e8a268a3-24f5-466d-a29a-8d0445351914
fit!(machc);

# ╔═╡ fb2540dd-9ec2-4a81-be65-28d0fcca50a8
md"We can inspect the learned parameters if we want:"

# ╔═╡ 201cbbfd-dcd2-457c-9a2e-c468345d87d1
fitted_params(machc).filler_given_feature

# ╔═╡ 5e39018e-ab09-41a2-b5fa-cb79ebf595ef
md"Next, we apply the learned transformation on our data:"

# ╔═╡ c1f700b7-6155-43db-91c5-524da38aa391
begin
  dfc     =  transform(machc, df)
  dfc_test = transform(machc, df_test)
  schema(dfc)
end

# ╔═╡ d5531602-881e-412d-ad90-b4405b216771
md"## Split the data into input features and target"

# ╔═╡ 8cdfa1e2-7881-42bf-895b-997a92b731e0
md"""
The following method puts the column with name equal to `:survived`
into the vector `y`, and everything else into a table (`DataFrame`)
called `X`.
"""

# ╔═╡ 8d7d9cdb-4dcf-407a-a525-e9b04a4bd246
begin
  y, X = unpack(dfc, ==(:survived));
  scitype(y)
end

# ╔═╡ 29bbd36f-5d25-43b6-80f0-ba7781e173cf
md"While we're here, we'll do the same for the holdout test set:"

# ╔═╡ 103d62ac-e7d0-4fd3-9cbc-9a2c39793333
y_test, X_test = unpack(dfc_test, ==(:survived));

# ╔═╡ 5fb0d820-3f4a-4974-b887-2b16710e5502
md"## Choosing an supervised model:"

# ╔═╡ 2ca455ea-0a5d-40c8-9452-5298a8a4a401
md"""
There are not many models that can directly handle a mixture of
scitypes, as we have here:
"""

# ╔═╡ db2d9ba2-1fc4-4a7f-b017-96f1602f2cad
models(matching(X, y))

# ╔═╡ 9e70bac7-6c1c-4fe4-8be2-2a4017c45345
md"""
This can be mitigated with further pre-processing (such as one-hot
encoding) but we'll settle for one the above models here:
"""

# ╔═╡ b517f63a-5d15-497c-a7ad-80d84f5b0070
doc("DecisionTreeClassifier", pkg="BetaML")

# ╔═╡ 01daecc9-68be-4f98-8378-5aa686f0b407
begin
  Tree = @load DecisionTreeClassifier pkg=BetaML  # model type
  tree = Tree()                                   # default instance
end

# ╔═╡ 187f489f-0d7e-4f8c-9f43-49763e8691a1
md"""
Notice that by calling `Tree` with no arguments we get default
values for the various hyperparameters that control how the tree is
trained. We specify keyword arguments to overide these defaults. For example:
"""

# ╔═╡ e9c248f5-559d-40d7-bb0e-3a45761c733a
small_tree = Tree(maxDepth=3)

# ╔═╡ edd14491-9fc4-4d0d-9979-7044b2f2df33
md"""
A decision tree is frequently not the best performing model, but it
is easy to interpret (and the algorithm is relatively easy to
explain). For example, here's an diagramatic representation of a
tree trained on (some part of) the Titanic data set, which suggests
how prediction works:
"""

# ╔═╡ 78c34e59-26f0-4bf8-b2a1-fbbde543f620
html"""
<div style="text-align: left";>
	<img src="https://upload.wikimedia.org/wikipedia/commons/5/58/Decision_Tree_-_survival_of_passengers_on_the_Titanic.jpg">
</div>
"""

# ╔═╡ 8674f741-da03-46f5-910b-f8a9a217eff2
md"## The fit/predict worflow"

# ╔═╡ 5879a6ad-8c92-4516-aa36-d2e8546da46a
md"""
We now the bind data to used for training and evaluation to the model
in a machine, just like we did for missing value imputation. In this
case, however, we also need to specify the training target `y`:
"""

# ╔═╡ 487955f9-4158-4f5e-88a1-a2bf91434413
macht = machine(tree, X, y)

# ╔═╡ f55550b3-b0eb-4ae7-a1cb-54e34396a855
md"To train using *all* the bound data:"

# ╔═╡ 890a342e-c900-4b6c-8037-0de5806e1a54
fit!(macht)

# ╔═╡ 44dfc2c1-45a6-4056-9961-a09632c33fb0
md"And get predictions on the holdout set:"

# ╔═╡ e056d831-fac2-4b79-b7cc-46f4ef988c68
p = predict(macht, X_test);

# ╔═╡ ddafd6fe-1c34-447d-90fb-7f2721f6fcc7
md"These are *probabilistic* predictions:"

# ╔═╡ a2741d2d-695b-457e-af65-ccd25ecb9818
p[3]

# ╔═╡ b8f0b521-794e-41ea-8890-979691212d9b
pdf(p[3], "0")

# ╔═╡ 3a3c9911-75b3-406d-a6fa-eaf14df5d44b
md"We can also get \"point\" predictions:"

# ╔═╡ fc5c195f-7ed5-4b56-8025-5084804a9f6c
yhat = mode.(p)

# ╔═╡ 6f02f83c-1aa6-4e90-9e90-09023d201062
md"We can evaluate performance using a probabilistic measure, as in"

# ╔═╡ 4fd67e05-c4d0-4858-b7bb-2f33ef765cc0
log_loss(p, y_test) |> mean

# ╔═╡ 7f127360-5da1-4bee-9625-01172c4a0081
md"Or using a deterministic measure:"

# ╔═╡ e5134375-cde5-41de-af4f-11c7de9e21dd
accuracy(yhat, y_test)

# ╔═╡ 9fbdd706-c10a-4634-8dba-241d9b744683
md"""
List all performance measures with `measures()`. Naturally, MLJ
includes functions to automate this kind of performance evaluation,
but this is beyond the scope of this tutorial. See, eg,
[here](https://alan-turing-institute.github.io/MLJ.jl/dev/getting_started/#Getting-Started).
"""

# ╔═╡ 3e2e6de9-bfd4-4629-a6e5-2f0b4dca5c59
md"## Learning more"

# ╔═╡ 72066eb3-9b46-4fa8-8550-20498aa03ed0
md"""
Some suggestions for next steps are
[here](https://alan-turing-institute.github.io/MLJ.jl/dev/getting_started/#Getting-Started).
"""

# ╔═╡ 135dac9b-0bd9-4e1d-9e7b-5b943cf6b560
md"""
---

*This notebook was generated using [Literate.jl](https://github.com/fredrikekre/Literate.jl).*
"""

# ╔═╡ Cell order:
# ╟─5dad6a5d-e6e9-4ea0-9bca-7c69b794f8ce
# ╟─33691746-74ed-425d-b795-033f6f2a0674
# ╟─aa49e638-95dc-4249-935f-ddf6a6bfbbdd
# ╟─b04c4790-59e0-42a3-af2a-25235e544a31
# ╟─1734e972-19e8-4d40-8af5-148d95ea2900
# ╠═4474fd86-9496-44c7-a6bf-47194d7e8e12
# ╟─6f4d110c-7f0b-4e70-828a-4cc485149963
# ╠═86f5ae82-8207-416e-9e54-3f7b3ca87ecb
# ╟─e5885e24-b17b-471b-ba1f-6363f43ec697
# ╠═d225419b-a250-425e-95ea-2955abd45275
# ╟─606143a8-2fb6-4fb9-b1b3-dd47e367ba54
# ╠═61e19dbd-3513-4813-8d7e-8e449afd1c48
# ╟─76750462-191b-43ac-a949-7f3bd292fe31
# ╠═5c2ec910-6444-4c53-8514-99938a2932db
# ╟─ddaf1934-1aba-4ede-a0de-1721c1bc2df2
# ╟─ca482134-299b-459a-bca8-7eec7950fd82
# ╟─c7a45cde-2f9b-47c9-9873-1b1430e635cc
# ╟─96c58ce9-9b29-4c5e-b43e-d0ebe87da176
# ╠═9d2f0b19-2942-47ac-9009-4cfb2012998f
# ╟─b90f3b7b-4de2-4a5c-abd3-cb77d7a79683
# ╠═4f8ae143-4f76-4d45-879e-dc128f3db7b3
# ╟─1d18aca8-11f4-4104-a367-9aa3c6cf34d0
# ╠═accd3a09-5371-45ab-bf32-94657e65284e
# ╟─45dd887b-332e-48ff-9afd-65a5b5facac9
# ╠═cc239a2b-2522-42c8-b6c8-54f5ed90a964
# ╟─4b4e8f45-6206-40f0-9292-fe822525fc77
# ╠═6e9599dd-e507-43e3-ae5e-4b83dcbc9675
# ╟─1e99474e-2fd8-4e7d-8a29-32f11452654a
# ╠═39a7b366-0330-4abd-a5f1-151fcbe229a2
# ╟─940f1ee2-f54d-4fa1-81bc-2d5603785a09
# ╠═069f1237-eb21-43cb-9d87-1d1fbb0e3997
# ╟─1e97e00e-d895-49d3-b950-fddef2a1fb10
# ╠═9e8fab47-3c20-4524-951b-64cb2a36c8e3
# ╟─8644107f-4b52-41ca-b0e6-441461cc8770
# ╟─4de9e07c-06b8-41a4-8cb0-de601961bc02
# ╠═0dcee734-f115-41af-a87d-950c50fb2955
# ╠═30eb5d8f-e6c4-4a50-8448-4bcb089096cd
# ╟─937fe069-98c9-45dd-a012-a84240254fb6
# ╟─fe8a8726-5047-4826-bbdd-9799f7bb2e60
# ╠═f49bb16f-aeeb-4fcd-97a7-88e3af4f10ee
# ╟─f94cdf23-d113-4386-b372-8c9866e51852
# ╟─bde9148b-79c2-4033-8f3d-b82f1e7b6f7a
# ╠═de5e2209-020b-4bce-ab04-579e5608ae53
# ╟─3ac76fef-0379-4d32-86cf-35420d9e6995
# ╠═e8a268a3-24f5-466d-a29a-8d0445351914
# ╟─fb2540dd-9ec2-4a81-be65-28d0fcca50a8
# ╠═201cbbfd-dcd2-457c-9a2e-c468345d87d1
# ╟─5e39018e-ab09-41a2-b5fa-cb79ebf595ef
# ╠═c1f700b7-6155-43db-91c5-524da38aa391
# ╟─d5531602-881e-412d-ad90-b4405b216771
# ╟─8cdfa1e2-7881-42bf-895b-997a92b731e0
# ╠═8d7d9cdb-4dcf-407a-a525-e9b04a4bd246
# ╟─29bbd36f-5d25-43b6-80f0-ba7781e173cf
# ╠═103d62ac-e7d0-4fd3-9cbc-9a2c39793333
# ╟─5fb0d820-3f4a-4974-b887-2b16710e5502
# ╟─2ca455ea-0a5d-40c8-9452-5298a8a4a401
# ╠═db2d9ba2-1fc4-4a7f-b017-96f1602f2cad
# ╟─9e70bac7-6c1c-4fe4-8be2-2a4017c45345
# ╠═b517f63a-5d15-497c-a7ad-80d84f5b0070
# ╠═01daecc9-68be-4f98-8378-5aa686f0b407
# ╟─187f489f-0d7e-4f8c-9f43-49763e8691a1
# ╠═e9c248f5-559d-40d7-bb0e-3a45761c733a
# ╟─edd14491-9fc4-4d0d-9979-7044b2f2df33
# ╟─78c34e59-26f0-4bf8-b2a1-fbbde543f620
# ╟─8674f741-da03-46f5-910b-f8a9a217eff2
# ╟─5879a6ad-8c92-4516-aa36-d2e8546da46a
# ╠═487955f9-4158-4f5e-88a1-a2bf91434413
# ╟─f55550b3-b0eb-4ae7-a1cb-54e34396a855
# ╠═890a342e-c900-4b6c-8037-0de5806e1a54
# ╟─44dfc2c1-45a6-4056-9961-a09632c33fb0
# ╠═e056d831-fac2-4b79-b7cc-46f4ef988c68
# ╟─ddafd6fe-1c34-447d-90fb-7f2721f6fcc7
# ╠═a2741d2d-695b-457e-af65-ccd25ecb9818
# ╠═b8f0b521-794e-41ea-8890-979691212d9b
# ╟─3a3c9911-75b3-406d-a6fa-eaf14df5d44b
# ╠═fc5c195f-7ed5-4b56-8025-5084804a9f6c
# ╟─6f02f83c-1aa6-4e90-9e90-09023d201062
# ╠═4fd67e05-c4d0-4858-b7bb-2f33ef765cc0
# ╟─7f127360-5da1-4bee-9625-01172c4a0081
# ╠═e5134375-cde5-41de-af4f-11c7de9e21dd
# ╟─9fbdd706-c10a-4634-8dba-241d9b744683
# ╟─3e2e6de9-bfd4-4629-a6e5-2f0b4dca5c59
# ╟─72066eb3-9b46-4fa8-8550-20498aa03ed0
# ╟─135dac9b-0bd9-4e1d-9e7b-5b943cf6b560
