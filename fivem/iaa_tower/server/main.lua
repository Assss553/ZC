AddEventHandler('onResourceStart', function(res)
  if res == GetCurrentResourceName() then
    print('^3[IAA Tower]^7 loaded. Put your .ydr/.ytyp/.ymap/.ybn/.ytd files in stream/.')
  end
end)
