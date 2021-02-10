local kap = import 'lib/kapitan.libjsonnet';
local inv = kap.inventory();
local params = inv.parameters.eventrouter;
local argocd = import 'lib/argocd.libjsonnet';

local app = argocd.App('eventrouter', params.namespace);

{
  eventrouter: app,
}
