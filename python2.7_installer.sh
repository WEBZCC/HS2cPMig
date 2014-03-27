# Installing the necessary packages
yum -y install gcc readline-devel sqlite-devel zlib-devel openssl-devel

# Installing Python in alternate location
clear
echo -e "Installing Python 2.7 in alternate location"
cd /usr/local/src 
wget https://www.python.org/ftp/python/2.7.6/Python-2.7.6.tgz --no-check-certificate
tar -xzf Python-2.7.6.tgz 
cd Python-2.7.6
./configure
make
make altinstall
cd ..

# Installing required python packages
clear 
echo -e "Insalling required Python packages"
wget https://pypi.python.org/packages/source/r/requests/requests-2.2.1.tar.gz --no-check-certificate
tar -xzf requests-2.2.1.tar.gz
cd requests-2.2.1
python2.7 setup.py install
cd ..

wget https://pypi.python.org/packages/source/p/pycpanel/pycpanel-0.1.3.tar.gz --no-check-certificate
tar -xzf pycpanel-0.1.3.tar.gz
cd pycpanel-0.1.3
python2.7 setup.py install
clear
echo -e "Python 2.7 and required Packages are installed"