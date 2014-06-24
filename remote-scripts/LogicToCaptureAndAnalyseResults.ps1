$result = @{}


#consider that test started here..
#Now we know the SubtestValue. So letus create a Multidimentional array -
$value = 2
$result[$value] = @{}
#Upto here, we have created array which will store the result according to subtests..
#from here, our test is again devided in to VIP and HOSTNAME EXECUTION.
#So, Each SubtestValue will have VIP and HOSTNAME.
#And Each scenario will have : pass, fail or aborted..
#so we need store that result in appropriate location. 
#Like > Result > SubtestValue > TestMode = FAIL/PASS
#so let's add location for  Test mode now -
$mode = "URL"
$result[$value][$mode] = @{}
#Now, we have added the mode and free to add the final result . Let's do it..
#Result will be stored at $result.2.URL
$testResult = "PASS"
$result.$value.$mode = $testResult
#Yess, we have executed, one test mode. Lets change the test mode and create anothere position in $result to hold the result.
$mode = "VIP"
$result[$value][$mode] = @{}
#We have created empty location $result.2.VIP
#Lets add the result.
$testResult = "PASS"
$result.$value.$mode = $testResult


#Now we are moving to next subset value.. Lets create empty block in $result..
$value = 3
$result[$value] = @{}
#Created!! Let's create a TestMoe Block
$mode = "URL"
$result[$value][$mode] = @{}
# A new location > $result.3.url
$testResult = "FAIL"
$result.$value.$mode = $testResult
$mode = "VIP"
$result[$value][$mode] = @{}
# A new location > $result.3.VIP
$testResult = "FAIL"
$result.$value.$mode = $testResult

#Now, we just need to Pass this $result to GetFinalizedResult funtion.
# I've just finished "How to extract $result."
# Please check it below :
foreach ($value in $result.Keys)
    {
        foreach ($mode in $result.$value.Keys)
            {
                foreach($finalResult in $result.$value.$mode)
                {
                    Write-Host "Subtest Value $value : Test Mode $mode : $finalResult"
                }
            }
    }

#with this, I'm just about to finish the GetFinalizedResult funtion.

#I tried a lot other ways to capture results like - result[0][1] array method, and creating object of the $result but those will desturb our current test execution and most IMPORTANT we need to capture Each Result for Each Test Mode in Each subtest.
#I thought, adding Hostname+VIP execution would be much easier. Yes it is but.. it's tricky..
#Now, I'm pretty sure, that, I'll do it very easily..